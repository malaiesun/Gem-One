import 'package:flutter/material.dart';

class SuggestionChips extends StatelessWidget {
  final List<String> hints;
  final Color accent;
  final void Function(String) onTap;

  const SuggestionChips({
    super.key,
    required this.hints,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: hints.map((h) => _Chip(text: h, accent: accent, onTap: () => onTap(h))).toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color accent;
  final VoidCallback onTap;

  const _Chip({required this.text, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: accent),
        ),
      ),
    );
  }
}
