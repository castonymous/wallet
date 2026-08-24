import 'package:flutter/material.dart';

class CardAppearanceSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const CardAppearanceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = {'photo', 'template', 'generated'}.contains(value)
        ? value
        : 'generated';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CARD APPEARANCE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'photo',
                icon: Icon(Icons.photo_outlined),
                label: Text('PHOTO'),
              ),
              ButtonSegment(
                value: 'template',
                icon: Icon(Icons.layers_outlined),
                label: Text('TEMPLATE'),
              ),
              ButtonSegment(
                value: 'generated',
                icon: Icon(Icons.gradient_outlined),
                label: Text('SIMPLE'),
              ),
            ],
            selected: {selected},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          switch (selected) {
            'photo' => 'The front image becomes the card itself. No generated text is placed over it.',
            'template' => 'Use your image as a custom card background and keep the card details overlay.',
            _ => 'Use the original generated gradient card design.',
          },
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}
