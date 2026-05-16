import 'package:flutter/material.dart';

import '../core/medical_search_service.dart';
import '../core/theme.dart';

import 'base_chat_screen.dart';

class MedicalScreen extends StatefulWidget {
  const MedicalScreen({
    super.key,
  });

  @override
  State<MedicalScreen> createState() =>
      _MedicalScreenState();
}

class _MedicalScreenState
    extends BaseChatState<MedicalScreen> {
  @override
  String get moduleName =>
      'Medical';

  @override
  IconData get moduleIcon =>
      Icons.medical_services_outlined;

  @override
  Color get moduleColor =>
      GemColors.medicalColor;

  @override
  String get inputHint =>
      'Describe symptoms or ask about a medicine…';

  @override
  String get systemPrompt => '';

  @override
  List<String> get emptyStateHints => [
        'What is paracetamol used for?',
        'Fever in a child - what to do?',
        'Signs of dehydration',
        'How to clean a wound',
      ];

  // internalPrompt carries the RAG-enriched context to the model while the
  // chat bubble still displays the user's original plain-text question.
  @override
  Future<void> sendMessage(
    String text, {
    String? internalPrompt,
  }) async {
    final results = MedicalSearchService.instance.search(text);
    final medicalContext = results.join('\n\n');

    final ragPrompt = '''
You are a helpful medical assistant.

Use the medical information below if relevant.

If the information is missing,
use your own medical knowledge.

Medical information:
$medicalContext

Question:
$text

Answer briefly and clearly.
''';
    await super.sendMessage(
      text,
      internalPrompt: ragPrompt,
    );
  }
}