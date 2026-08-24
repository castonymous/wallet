import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wallet/models/card_color_data.dart';
import 'package:wallet/widgets/encrypted_image_display.dart';
import '../models/db_helper.dart';

class GlassCreditCard extends StatefulWidget {
  final Wallet wallet;
  final bool isMasked;
  final VoidCallback onCardTap;

  /// Optional unencrypted preview used only while adding/editing a card.
  /// Saved cards continue to use encrypted image storage.
  final File? previewImageFile;
  final String? previewDisplayMode;
  final File? previewLogoFile;

  const GlassCreditCard({
    super.key,
    required this.wallet,
    required this.isMasked,
    required this.onCardTap,
    this.previewImageFile,
    this.previewDisplayMode,
    this.previewLogoFile,
  });

  @override
  State<GlassCreditCard> createState() => _GlassCreditCardState();
}

class _GlassCreditCardState extends State<GlassCreditCard> {
  static final RegExp _fourDigitPattern = RegExp(r'.{4}');

  String _formatCardNumber(String input) {
    return input.replaceAllMapped(
      _fourDigitPattern,
      (match) => '${match.group(0)} ',
    );
  }

  String _formatExpiry(String input) {
    if (input.length != 4) return input.isEmpty ? 'MM/YY' : input;
    return '${input.substring(0, 2)}/${input.substring(2, 4)}';
  }

  bool get _hasFrontImage =>
      widget.previewImageFile != null ||
      (widget.wallet.frontImagePath?.isNotEmpty ?? false);

  String get _displayMode {
    final requested = widget.previewDisplayMode ?? widget.wallet.displayMode;
    if (!_hasFrontImage && requested != 'generated') return 'generated';
    return {'photo', 'template', 'generated'}.contains(requested)
        ? requested
        : 'generated';
  }

  @override
  Widget build(BuildContext context) {
    final lastFour = widget.wallet.number.length >= 4
        ? widget.wallet.number.substring(widget.wallet.number.length - 4)
        : widget.wallet.number;

    final String colorKey = widget.wallet.color ?? '#0F0F0F';
    final CardColorData colorData = CardColorData.fromHexOrKey(colorKey);

    return Material(
      color: Colors.transparent,
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: widget.onCardTap,
          child: AspectRatio(
            aspectRatio: 1.586,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_displayMode == 'generated')
                    _GeneratedBackground(colorData: colorData)
                  else
                    _buildImageBackground(),

                  if (_displayMode == 'template') ...[
                    const _TemplateReadabilityLayer(),
                    _buildCardDetails(lastFour),
                  ],

                  if (_displayMode == 'generated')
                    _buildCardDetails(lastFour),

                  // Very subtle edge keeps photographed white cards visible
                  // against a light app background without altering the image.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.10),
                          width: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageBackground() {
    final preview = widget.previewImageFile;
    if (preview != null) {
      return Image.file(
        preview,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }

    final path = widget.wallet.frontImagePath;
    if (path != null && path.isNotEmpty) {
      return EncryptedImageDisplay(
        imagePath: path,
        fit: BoxFit.cover,
        cacheWidth: 1200,
      );
    }

    return const ColoredBox(color: Color(0xFF111111));
  }

  Widget _buildCardDetails(String lastFour) {
    final shownNumber = widget.wallet.number.isEmpty
        ? 'CARD NUMBER'
        : widget.isMasked
            ? '••••  ••••  ••••  $lastFour'
            : _formatCardNumber(widget.wallet.number).trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.contactless_rounded,
                color: Colors.white.withValues(alpha: 0.82),
                size: 32,
              ),
              SizedBox(
                height: 36,
                child: _CardLogo(wallet: widget.wallet, previewLogoFile: widget.previewLogoFile),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              shownNumber,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.96),
                letterSpacing: 2.0,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  widget.wallet.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                  ),
                ),
              ),
              if (widget.wallet.expiry.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    widget.isMasked ? '••/••' : _formatExpiry(widget.wallet.expiry),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GeneratedBackground extends StatelessWidget {
  final CardColorData colorData;

  const _GeneratedBackground({required this.colorData});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [
            colorData.accent,
            colorData.secondary,
            colorData.primary,
          ],
        ),
      ),
    );
  }
}

class _TemplateReadabilityLayer extends StatelessWidget {
  const _TemplateReadabilityLayer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.42),
          ],
        ),
      ),
    );
  }
}

class _CardLogo extends StatelessWidget {
  final Wallet wallet;
  final File? previewLogoFile;

  const _CardLogo({required this.wallet, this.previewLogoFile});

  @override
  Widget build(BuildContext context) {
    if (previewLogoFile != null) {
      return Image.file(previewLogoFile!, fit: BoxFit.contain, filterQuality: FilterQuality.high);
    }
    final customPath = wallet.logoImagePath;
    if (customPath != null && customPath.isNotEmpty) {
      return EncryptedImageDisplay(
        imagePath: customPath,
        fit: BoxFit.contain,
        cacheHeight: 160,
        cacheWidth: 320,
      );
    }
    return _NetworkLogo(network: wallet.network);
  }
}

class _NetworkLogo extends StatelessWidget {
  final String? network;

  const _NetworkLogo({required this.network});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/network/${network ?? 'visa'}.png',
      fit: BoxFit.contain,
      height: 30,
      color: Colors.white,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          (network ?? 'CARD').toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }
}
