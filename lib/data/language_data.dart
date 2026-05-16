class LangInfo {
  final String code;
  final String name;
  final String flag;
  final String ttsLocale;
  final bool isBeta;

  const LangInfo({
    required this.code,
    required this.name,
    required this.flag,
    required this.ttsLocale,
    this.isBeta = false,
  });
}

class LangLesson {
  final String id;
  final String title;
  final List<LangItem> items;

  const LangLesson({
    required this.id,
    required this.title,
    required this.items,
  });
}

class LangItem {
  final String text;       // native script
  final String romanized;  // pronunciation guide
  final String meaning;    // English meaning
  final String? example;
  final String? exampleMeaning;

  const LangItem({
    required this.text,
    required this.romanized,
    required this.meaning,
    this.example,
    this.exampleMeaning,
  });
}

// isBeta marks languages where Gemma 4B produces lower-quality output
// (non-Latin scripts, morphologically complex languages).
const kLanguages = <LangInfo>[
  LangInfo(code:'es', name:'Spanish',    flag:'🇪🇸', ttsLocale:'es-ES'),
  LangInfo(code:'fr', name:'French',     flag:'🇫🇷', ttsLocale:'fr-FR'),
  LangInfo(code:'de', name:'German',     flag:'🇩🇪', ttsLocale:'de-DE', isBeta:true),
  LangInfo(code:'ja', name:'Japanese',   flag:'🇯🇵', ttsLocale:'ja-JP'),
  LangInfo(code:'ko', name:'Korean',     flag:'🇰🇷', ttsLocale:'ko-KR'),
  LangInfo(code:'it', name:'Italian',    flag:'🇮🇹', ttsLocale:'it-IT', isBeta:true),
  LangInfo(code:'pt', name:'Portuguese', flag:'🇧🇷', ttsLocale:'pt-BR', isBeta:true),
  LangInfo(code:'zh', name:'Mandarin',   flag:'🇨🇳', ttsLocale:'zh-CN', isBeta:true),
  LangInfo(code:'ru', name:'Russian',    flag:'🇷🇺', ttsLocale:'ru-RU', isBeta:true),
  LangInfo(code:'ar', name:'Arabic',     flag:'🇸🇦', ttsLocale:'ar-SA', isBeta:true),
  LangInfo(code:'hi', name:'Hindi',      flag:'🇮🇳', ttsLocale:'hi-IN'),
  LangInfo(code:'tr', name:'Turkish',    flag:'🇹🇷', ttsLocale:'tr-TR', isBeta:true),
  LangInfo(code:'nl', name:'Dutch',      flag:'🇳🇱', ttsLocale:'nl-NL', isBeta:true),
  LangInfo(code:'vi', name:'Vietnamese', flag:'🇻🇳', ttsLocale:'vi-VN', isBeta:true),
  LangInfo(code:'id', name:'Indonesian', flag:'🇮🇩', ttsLocale:'id-ID', isBeta:true),
  LangInfo(code:'bn', name:'Bengali',    flag:'🇧🇩', ttsLocale:'bn-IN', isBeta:true),
  LangInfo(code:'sw', name:'Swahili',    flag:'🇰🇪', ttsLocale:'sw',    isBeta:true),
  LangInfo(code:'ta', name:'Tamil',      flag:'🇮🇳', ttsLocale:'ta-IN'),
];

// Throws StateError if code is not in the registry - intentional; callers must use valid codes.
LangInfo langFor(String code) => kLanguages.firstWhere((l) => l.code == code);
