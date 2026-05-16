import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'base_chat_screen.dart';

class MathScreen extends StatefulWidget {
  const MathScreen({super.key});

  @override
  State<MathScreen> createState() => _MathScreenState();
}

class _MathScreenState extends BaseChatState<MathScreen> {
  @override
  String get moduleName => 'Maths';

  @override
  IconData get moduleIcon => Icons.calculate_outlined;

  @override
  Color get moduleColor => GemColors.mathColor;

  @override
  String get inputHint => 'Type a problem or equation…';

  @override
String get systemPrompt => '''
You are a maths tutor.

Solve step-by-step.
Be short and clear.
Use numbered steps.
''';

  @override
  List<String> get emptyStateHints => [
    'Solve 3x + 7 = 22',
    'What is 15% of 480?',
    'Area of a triangle with base 8 and height 5',
    'Explain fractions with an example',
  ];
}