import 'package:flutter/material.dart';
import 'package:wallet/models/identity_card.dart';
import 'package:wallet/models/card_color_data.dart';
import 'package:wallet/widgets/encrypted_image_display.dart';

class IdentityCardWidget extends StatelessWidget {
  final IdentityCard card;
  final VoidCallback onTap;

  const IdentityCardWidget({
    super.key,
    required this.card,
    required this.onTap,
  });

  bool get _hasImage => card.frontImagePath?.isNotEmpty ?? false;

  String get _displayMode {
    if (!_hasImage && card.displayMode != 'generated') return 'generated';
    return {'photo', 'template', 'generated'}.contains(card.displayMode)
        ? card.displayMode
        : 'generated';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorKey = card.color ?? (isDark ? '#0F0F0F' : '#1E293B');
    final colorData = CardColorData.fromHexOrKey(colorKey, isDark: isDark);

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.586,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_displayMode == 'generated')
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorData.accent,
                        colorData.secondary,
                        colorData.primary,
                      ],
                    ),
                  ),
                )
              else
                EncryptedImageDisplay(
                  imagePath: card.frontImagePath!,
                  fit: BoxFit.cover,
                  cacheWidth: 1200,
                ),

              if (_displayMode == 'template')
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.50),
                      ],
                    ),
                  ),
                ),

              if (_displayMode != 'photo') _buildGeneratedContent(),

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
    );
  }

  Widget _buildGeneratedContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.cardType.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                  ),
                ),
              ),
              const Icon(Icons.nfc_rounded, size: 20, color: Colors.white70),
            ],
          ),
          const Spacer(),
          const Text(
            'NAME',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.white70,
              shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'DOCUMENT NUMBER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.white70,
              shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontFamily: 'Courier',
              letterSpacing: 1.2,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
            ),
          ),
        ],
      ),
    );
  }
}
