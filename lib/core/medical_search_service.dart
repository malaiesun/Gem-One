import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class MedicalSearchService {
  static final instance =
      MedicalSearchService._();

  MedicalSearchService._();

  List<dynamic> _brain = [];

  bool _loaded = false;

  Future<void> init() async {
    // Guard prevents re-parsing the 28.5 MB JSON file on repeated calls.
    if (_loaded) return;

    final jsonString =
        await rootBundle.loadString(
      'lib/medical_data/medical_brain.json',
    );

    _brain = json.decode(jsonString);

    _loaded = true;
  }

  List<String> search(
    String query,
  ) {
    if (_brain.isEmpty) {
      return [];
    }

    final queryWords = query
        .toLowerCase()
        .split(RegExp(r'\s+'));

    final scored =
        <Map<String, dynamic>>[];

    for (final item in _brain) {
      final rawText =
          item['text'].toString();

      // The source JSON contains HTML markup from its original web scrape.
      final cleanedText = rawText
          .replaceAll(
            RegExp(r'<[^>]*>'),
            '',
          )
          .replaceAll('\n', ' ')
          .replaceAll(
            RegExp(r'\s+'),
            ' ',
          );

      final lower =
          cleanedText.toLowerCase();

      int score = 0;

      for (final word in queryWords) {
        // Skip stop-words and short tokens that would produce noisy matches.
        if (word.length < 3) continue;

        if (lower.contains(word)) {
          score++;
        }
      }

      if (score > 0) {
        scored.add({
          // 700-char cap keeps the injected RAG context within the model's practical context budget.
          'text': cleanedText.substring(
            0,
            min(
              700,
              cleanedText.length,
            ),
          ),
          'score': score,
        });
      }
    }

    scored.sort(
      (a, b) =>
          b['score'].compareTo(a['score']),
    );

    // Only the top result is injected; returning more would overflow the context window.
    return scored
        .take(1)
        .map(
          (e) => e['text'].toString(),
        )
        .toList();
  }
}