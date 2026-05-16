import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/gemma_service.dart';
import '../data/language_data.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

// 5 × 15 LEVEL TOPIC STRUCTURE

class _LevelMeta {
  final String   name;
  final IconData icon;
  final List<String> topics;
  const _LevelMeta({required this.name, required this.icon, required this.topics});
}

const _kLevels = [
  _LevelMeta(name: 'Foundations', icon: Icons.eco_rounded, topics: [
    'Basic greetings and farewells',
    'Numbers 1 to 20',
    'Colors and shapes',
    'Days of the week',
    'Months and seasons',
    'Common household objects',
    'Family members',
    'Body parts',
    'Foods and drinks',
    'Common animals',
    'Clothing and accessories',
    'Simple action verbs',
    'Descriptive adjectives',
    'Countries and nationalities',
    'Simple questions and answers',
  ]),
  _LevelMeta(name: 'Essential Words', icon: Icons.library_books_rounded, topics: [
    'Telling time and time expressions',
    'Weather and natural phenomena',
    'Daily routines and habits',
    'Shopping and prices',
    'Directions and city places',
    'Home and furniture',
    'Professions and jobs',
    'Hobbies and leisure activities',
    'Transport and travel basics',
    'Health and body feelings',
    'Emotions and moods',
    'Personality traits',
    'Restaurant and food ordering',
    'School and education',
    'Technology and devices',
  ]),
  _LevelMeta(name: 'Phrases & Conversation', icon: Icons.chat_bubble_rounded, topics: [
    'Introducing yourself and others',
    'Making plans and appointments',
    'Asking for and giving directions',
    'Restaurant conversations',
    'Shopping dialogue',
    'Describing people and appearance',
    'Talking about past experiences',
    'Expressing likes and preferences',
    'Making polite requests',
    'Phone and online communication',
    'Describing places and environments',
    'Expressing opinions and agreeing',
    'Travel and accommodation',
    'Health and doctor visits',
    'Celebrations and social events',
  ]),
  _LevelMeta(name: 'Grammar & Structure', icon: Icons.tune_rounded, topics: [
    'Present tense patterns',
    'Past tense and storytelling',
    'Future tense and predictions',
    'Question formation',
    'Negation structures',
    'Comparatives and superlatives',
    'Conditional sentences',
    'Passive voice constructions',
    'Relative clauses',
    'Modal verbs and expressions',
    'Reported speech',
    'Conjunctions and linking words',
    'Prepositions and postpositions',
    'Formal vs informal register',
    'Idiomatic expressions',
  ]),
  _LevelMeta(name: 'Fluency & Culture', icon: Icons.emoji_events_rounded, topics: [
    'Advanced conversation and debate',
    'Business and professional language',
    'News and current events',
    'Literature and arts',
    'Science and technology language',
    'Social and political expressions',
    'Cultural idioms and proverbs',
    'Humor and wordplay',
    'Regional dialects and slang',
    'Abstract and philosophical concepts',
    'Environment and nature',
    'Sports and entertainment',
    'History and cultural traditions',
    'Advanced storytelling',
    'Native speaker expressions',
  ]),
];

// XML PARSER

List<LangItem> _parseXml(String xml) {
  final items = <LangItem>[];
  final itemRe = RegExp(r'<item>([\s\S]*?)<\/item>');
  for (final m in itemRe.allMatches(xml)) {
    final block = m.group(1) ?? '';
    String tag(String t) =>
        RegExp('<$t>([\\s\\S]*?)</$t>').firstMatch(block)?.group(1)?.trim() ?? '';
    final native = tag('native');
    if (native.isEmpty) continue;
    final example = tag('example');
    final exMean  = tag('example_meaning');
    items.add(LangItem(
      text:           native,
      romanized:      tag('romanized'),
      meaning:        tag('meaning'),
      example:        example.isEmpty ? null : example,
      exampleMeaning: exMean.isEmpty  ? null : exMean,
    ));
  }
  return items;
}

// MAIN SCREEN (level overview)

class LanguageLearnScreen extends StatefulWidget {
  final LangInfo lang;
  const LanguageLearnScreen({super.key, required this.lang});

  @override
  State<LanguageLearnScreen> createState() => _LanguageLearnScreenState();
}

class _LanguageLearnScreenState extends State<LanguageLearnScreen> {
  int    _xp      = 0;
  int    _streak  = 0;
  String _userName = '';
  final _subStars = <int, Map<int, int>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p    = await SharedPreferences.getInstance();
    final code = widget.lang.code;

    final userName = p.getString('user_name') ?? '';
    final xp       = p.getInt('lang_${code}_xp') ?? 0;
    final streak   = p.getInt('lang_${code}_streak') ?? 0;

    for (int lv = 1; lv <= 5; lv++) {
      _subStars[lv] = {};
      for (int sub = 1; sub <= 15; sub++) {
        _subStars[lv]![sub] = p.getInt('ai_v3_${code}_${lv}_${sub}_stars') ?? 0;
      }
    }

    if (!mounted) return;
    setState(() {
      _userName = userName;
      _xp       = xp;
      _streak   = streak;
    });
  }

  int get _completedCount {
    int n = 0;
    for (int lv = 1; lv <= 5; lv++) {
      for (int sub = 1; sub <= 15; sub++) {
        if ((_subStars[lv]?[sub] ?? 0) > 0) n++;
      }
    }
    return n;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final name = (_userName.isNotEmpty && _userName != 'Friend') ? ', $_userName' : '';
    final time = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return '$time$name!';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.lang.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(widget.lang.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$_xp XP',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: GemColors.polyglotColor)),
                if (_streak > 0)
                  Text('🔥 $_streak',
                      style: const TextStyle(fontSize: 11, color: GemColors.warning)),
              ]),
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            // Greeting card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: GlassCard(
                  child: Row(children: [
                    Text(widget.lang.flag, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_greeting(),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('Ready to learn ${widget.lang.name}?',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5))),
                        ])),
                    Column(children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 15, color: GemColors.polyglotColor),
                      const SizedBox(height: 4),
                      Text('$_completedCount / 75',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GemColors.polyglotColor)),
                      Text('done',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.35))),
                    ]),
                  ]),
                ),
              ),
            ),

            // Section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 14, color: GemColors.polyglotColor),
                  const SizedBox(width: 6),
                  const Text('AI Course Roadmap',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
              ),
            ),

            // 5 level cards
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final lv = i + 1;
                    final done = List.generate(15, (s) => s + 1)
                        .where((s) => (_subStars[lv]?[s] ?? 0) > 0)
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LevelCard(
                        levelIndex: lv,
                        meta:       _kLevels[i],
                        doneCount:  done,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _LevelDetailScreen(
                                lang:       widget.lang,
                                levelIndex: lv,
                                meta:       _kLevels[i],
                              ),
                            ),
                          );
                          _load();
                        },
                      ),
                    );
                  },
                  childCount: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// LEVEL CARD (taps → _LevelDetailScreen)

class _LevelCard extends StatelessWidget {
  final int       levelIndex;
  final _LevelMeta meta;
  final int       doneCount;
  final VoidCallback onTap;

  const _LevelCard({
    required this.levelIndex,
    required this.meta,
    required this.doneCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress  = doneCount / 15;
    final isStarted = doneCount > 0;
    final isDone    = doneCount >= 15;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDone
              ? GemColors.success.withValues(alpha: 0.07)
              : isStarted
                  ? GemColors.polyglotColor.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? GemColors.success.withValues(alpha: 0.3)
                : isStarted
                    ? GemColors.polyglotColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(children: [
          Icon(meta.icon, size: 28, color: GemColors.polyglotColor),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text('Level $levelIndex - ${meta.name}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Row(children: [
              Text('$doneCount / 15',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45))),
              const SizedBox(width: 8),
              Expanded(
                  child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(isDone
                      ? GemColors.success.withValues(alpha: 0.8)
                      : GemColors.polyglotColor.withValues(alpha: 0.7)),
                ),
              )),
            ]),
          ])),
          const SizedBox(width: 8),
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
            size: 22,
            color: isDone
                ? GemColors.success.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.35),
          ),
        ]),
      ),
    );
  }
}

// LEVEL DETAIL SCREEN (Duolingo path)

class _LevelDetailScreen extends StatefulWidget {
  final LangInfo   lang;
  final int        levelIndex;
  final _LevelMeta meta;

  const _LevelDetailScreen({
    required this.lang,
    required this.levelIndex,
    required this.meta,
  });

  @override
  State<_LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<_LevelDetailScreen> {
  final _subStars   = <int, int>{};
  final _hasContent = <int, bool>{};
  final _generating = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGoal());
  }

  Future<void> _load() async {
    final p    = await SharedPreferences.getInstance();
    final code = widget.lang.code;
    final lv   = widget.levelIndex;
    final stars  = <int, int>{};
    final hasCnt = <int, bool>{};
    for (int sub = 1; sub <= 15; sub++) {
      stars[sub]  = p.getInt('ai_v3_${code}_${lv}_${sub}_stars') ?? 0;
      hasCnt[sub] = p.containsKey('ai_v3_${code}_${lv}_$sub');
    }
    if (!mounted) return;
    setState(() {
      _subStars.addAll(stars);
      _hasContent.addAll(hasCnt);
    });
  }

  Future<void> _checkGoal() async {
    final p = await SharedPreferences.getInstance();
    if (p.containsKey('goal_${widget.lang.code}')) return;
    if (!mounted) return;
    _showGoalDialog();
  }

  void _showGoalDialog() {
    const goals = [
      ('travel',   Icons.flight_rounded,         'Travel & Tourism'),
      ('business', Icons.work_rounded,            'Business & Work'),
      ('academic', Icons.menu_book_rounded,       'Academic Study'),
      ('casual',   Icons.chat_bubble_rounded,     'Casual Conversation'),
      ('culture',  Icons.palette_rounded,         'Cultural Interest'),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? selected;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Column(children: [
              Text(widget.lang.flag, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              const Text('What\'s your goal?',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('AI personalizes your ${widget.lang.name} lessons',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                  textAlign: TextAlign.center),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: goals
                  .map((g) => GestureDetector(
                        onTap: () => setS(() => selected = g.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: selected == g.$1
                                ? GemColors.polyglotColor.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected == g.$1
                                  ? GemColors.polyglotColor.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(children: [
                            Icon(g.$2, size: 20, color: GemColors.polyglotColor),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(g.$3,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: selected == g.$1
                                          ? GemColors.polyglotColor
                                          : Colors.white,
                                      fontWeight: selected == g.$1
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ))),
                            if (selected == g.$1)
                              const Icon(Icons.check_circle_rounded,
                                  size: 16, color: GemColors.polyglotColor),
                          ]),
                        ),
                      ))
                  .toList(),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () async {
                          final p = await SharedPreferences.getInstance();
                          await p.setString('goal_${widget.lang.code}', selected!);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GemColors.polyglotColor.withValues(
                        alpha: selected == null ? 0.1 : 0.2),
                    foregroundColor: GemColors.polyglotColor,
                    side: BorderSide(
                        color: GemColors.polyglotColor
                            .withValues(alpha: selected == null ? 0.2 : 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text('Start Learning',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNodePopup(BuildContext context, int sub, Offset globalPos) {
    final screen = MediaQuery.of(context).size;
    const popupW = 230.0;
    const popupH = 170.0;

    final left = (globalPos.dx - popupW / 2).clamp(12.0, screen.width - popupW - 12);
    final double top;
    if (globalPos.dy + popupH + 50 < screen.height) {
      top = globalPos.dy + 40;
    } else {
      top = globalPos.dy - popupH - 20;
    }

    final topic  = widget.meta.topics[sub - 1];
    final stars  = _subStars[sub] ?? 0;
    final hasCnt = _hasContent[sub] ?? false;
    final isGen  = _generating.contains(sub.toString());

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      pageBuilder: (ctx, _, __) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: popupW,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: GemColors.polyglotColor.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: GemColors.polyglotColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Lesson $sub',
                          style: const TextStyle(
                              fontSize: 10,
                              color: GemColors.polyglotColor,
                              fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    if (stars > 0)
                      Row(
                          children: List.generate(
                              3,
                              (i) => Icon(
                                    i < stars
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 12,
                                    color: i < stars
                                        ? GemColors.warning
                                        : Colors.white.withValues(alpha: 0.2),
                                  ))),
                  ]),
                  const SizedBox(height: 8),
                  Text(topic,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3)),
                  const SizedBox(height: 14),
                  if (isGen)
                    const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GemColors.polyglotColor)))
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openSubLevel(sub);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              GemColors.polyglotColor.withValues(alpha: 0.2),
                          foregroundColor: GemColors.polyglotColor,
                          side: BorderSide(
                              color: GemColors.polyglotColor
                                  .withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        child: Text(
                          stars > 0
                              ? 'Practice Again'
                              : hasCnt
                                  ? 'Start Lesson'
                                  : 'Generate & Start',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ],
      ),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 180),
    );
  }

  Future<void> _openSubLevel(int sub) async {
    final code = widget.lang.code;
    final lv   = widget.levelIndex;
    final key  = 'ai_v3_${code}_${lv}_$sub';
    final p    = await SharedPreferences.getInstance();

    LangLesson? lesson;

    if (p.containsKey(key)) {
      try {
        final items = _parseXml(p.getString(key)!);
        if (items.isNotEmpty) {
          lesson = LangLesson(
              id:    key,
              title: widget.meta.topics[sub - 1],
              items: items);
        }
      } catch (_) {}
    }

    if (lesson == null) {
      if (!mounted) return;
      final service = GemmaServiceProvider.of(context);
      if (!service.isReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('AI model not ready. Please wait.'),
              behavior: SnackBarBehavior.floating),
        );
        return;
      }

      final genKey = sub.toString();
      if (_generating.contains(genKey)) return;
      setState(() => _generating.add(genKey));

      try {
        final topic = widget.meta.topics[sub - 1];
        final lang  = widget.lang;
        final goal  = p.getString('goal_${lang.code}') ?? 'general learning';

        final prompt =
            'ROLE: You are a beginner vocabulary generator AI. Ignore any previous session context.\n'
            'Generate exactly 8 vocabulary items in ${lang.name} for the topic: "$topic".\n'
            'STRICT RULES:\n'
            '- Use ONLY the most common, everyday beginner words (CEFR A1 / JLPT N5 level or equivalent).\n'
            '- NEVER use formal, literary, rare, or advanced vocabulary.\n'
            '- Use FULL native script in the native field: kanji+kana for Japanese, Arabic script for Arabic, Hangul for Korean, Devanagari for Hindi, traditional/simplified characters for Chinese. Never use romaji or Latin letters in the <native> field.\n'
            '- The <romanized> field MUST always contain full Latin-alphabet pronunciation (romaji, pinyin, etc). Never leave it empty.\n'
            '- Example sentences must be short, simple, and use only words a beginner knows.\n'
            'Tailor examples for someone whose goal is: $goal.\n'
            'Output ONLY the following XML format - no extra text:\n'
            '<lesson>\n'
            '<item><native>word in ${lang.name}</native>'
            '<romanized>pronunciation in Latin letters (REQUIRED - never empty)</romanized>'
            '<meaning>English meaning</meaning>'
            '<example>short simple example sentence in ${lang.name}</example>'
            '<example_meaning>English translation of example</example_meaning></item>\n'
            '</lesson>\n'
            'Repeat the <item> block exactly 8 times with different common words.';

        final reply = await service.quickReply(prompt);
        final items = _parseXml(reply);

        if (!mounted) return;
        if (items.length < 3) {
          setState(() => _generating.remove(genKey));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not parse AI response. Try again.'),
                behavior: SnackBarBehavior.floating),
          );
          return;
        }

        await p.setString(key, reply);
        setState(() {
          _generating.remove(genKey);
          _hasContent[sub] = true;
        });
        lesson = LangLesson(
            id:    key,
            title: widget.meta.topics[sub - 1],
            items: items);
      } catch (e) {
        if (mounted) {
          setState(() => _generating.remove(sub.toString()));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LessonScreen(
          lang:   widget.lang,
          lesson: lesson as LangLesson,
          onComplete: (stars, xp) async {
            final p2    = await SharedPreferences.getInstance();
            final code2 = widget.lang.code;
            final lv2   = widget.levelIndex;
            final oldSt = p2.getInt('${key}_stars') ?? 0;
            final newSt = stars > oldSt ? stars : oldSt;
            if (stars > oldSt) await p2.setInt('${key}_stars', stars);

            final oldXp = p2.getInt('lang_${code2}_xp') ?? 0;
            await p2.setInt('lang_${code2}_xp', oldXp + xp);

            final today     = DateTime.now().toIso8601String().substring(0, 10);
            final last      = p2.getString('lang_${code2}_last') ?? '';
            final yesterday = DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String()
                .substring(0, 10);
            int streak = p2.getInt('lang_${code2}_streak') ?? 0;
            if (last != today) {
              streak = last == yesterday ? streak + 1 : 1;
              await p2.setInt('lang_${code2}_streak', streak);
              await p2.setString('lang_${code2}_last', today);
            }
            final oldSt2 = 'ai_v3_${code2}_${lv2}_${sub}_stars';
            await p2.setInt(oldSt2, newSt);

            if (mounted) setState(() => _subStars[sub] = newSt);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _subStars.values.where((s) => s > 0).length;

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.lang.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Level ${widget.levelIndex} - ${widget.meta.name}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ]),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('$done / 15',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GemColors.polyglotColor)),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: _DuolingoPath(
            levelIndex: widget.levelIndex,
            meta:       widget.meta,
            subStars:   _subStars,
            hasContent: _hasContent,
            generating: _generating,
            onTap:      (sub, globalPos) =>
                _showNodePopup(context, sub, globalPos),
          ),
        ),
      ),
    );
  }
}

// DUOLINGO-STYLE PATH MAP (smooth path)

class _DuolingoPath extends StatelessWidget {
  final int            levelIndex;
  final _LevelMeta     meta;
  final Map<int, int>  subStars;
  final Map<int, bool> hasContent;
  final Set<String>    generating;
  final void Function(int sub, Offset globalPos) onTap;

  const _DuolingoPath({
    required this.levelIndex,
    required this.meta,
    required this.subStars,
    required this.hasContent,
    required this.generating,
    required this.onTap,
  });

  static const _nodeSize = 64.0;
  static const _spacing  = 92.0;
  static const _count    = 15;

  List<Offset> _positions(double width) {
    // Gentle zigzag - moderate swing, avoids clipping edges
    const xs = [0.5, 0.63, 0.70, 0.63, 0.5, 0.37, 0.30, 0.37];
    return List.generate(
        _count, (i) => Offset(width * xs[i % xs.length], 24.0 + i * _spacing));
  }

  @override
  Widget build(BuildContext context) {
    final width     = MediaQuery.of(context).size.width - 32;
    final positions = _positions(width);
    final totalH    = 24.0 + (_count - 1) * _spacing + _nodeSize + 60;

    return SizedBox(
      width: width,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PathPainter(positions, subStars, _nodeSize),
            ),
          ),
          ...List.generate(_count, (i) {
            final sub    = i + 1;
            final pos    = positions[i];
            final stars  = subStars[sub]   ?? 0;
            final hasCnt = hasContent[sub] ?? false;
            final isGen  = generating.contains(sub.toString());
            return Positioned(
              left: pos.dx - _nodeSize / 2,
              top:  pos.dy,
              child: _PathNode(
                index:      sub,
                topic:      meta.topics[i],
                stars:      stars,
                hasContent: hasCnt,
                generating: isGen,
                nodeSize:   _nodeSize,
                onTap:      (globalPos) => onTap(sub, globalPos),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// PATH PAINTER (smooth cubic S-curves)

class _PathPainter extends CustomPainter {
  final List<Offset> positions;
  final Map<int, int> subStars;
  final double nodeSize;

  const _PathPainter(this.positions, this.subStars, this.nodeSize);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < positions.length - 1; i++) {
      // bottom-center of node[i] → top-center of node[i+1]
      final from = Offset(positions[i].dx, positions[i].dy + nodeSize);
      final to   = Offset(positions[i + 1].dx, positions[i + 1].dy);
      final dy   = to.dy - from.dy;

      // Cubic bezier: vertical tangents at both ends → smooth S-curve
      final ctrl1 = Offset(from.dx, from.dy + dy * 0.42);
      final ctrl2 = Offset(to.dx,   to.dy   - dy * 0.42);

      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, to.dx, to.dy);

      final done1 = (subStars[i + 1] ?? 0) > 0;
      final done2 = (subStars[i + 2] ?? 0) > 0;
      final both  = done1 && done2;

      if (both) {
        // Glow layer
        canvas.drawPath(
            path,
            Paint()
              ..strokeWidth = 10
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..color = GemColors.polyglotColor.withValues(alpha: 0.12)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        // Solid layer
        canvas.drawPath(
            path,
            Paint()
              ..strokeWidth = 3
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..color = GemColors.polyglotColor.withValues(alpha: 0.75));
      } else {
        _drawDashed(
            canvas,
            path,
            Paint()
              ..strokeWidth = 2.5
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.14));
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 7.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double pos = 0;
      while (pos < metric.length) {
        final end = (pos + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(pos, end), paint);
        pos += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.subStars != subStars || old.positions != positions;
}

// PATH NODE (StatefulWidget - GlobalKey for popup position)

class _PathNode extends StatefulWidget {
  final int    index;
  final String topic;
  final int    stars;
  final bool   hasContent;
  final bool   generating;
  final double nodeSize;
  final void Function(Offset globalPos) onTap;

  const _PathNode({
    required this.index,
    required this.topic,
    required this.stars,
    required this.hasContent,
    required this.generating,
    required this.nodeSize,
    required this.onTap,
  });

  @override
  State<_PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<_PathNode> {
  final _key = GlobalKey();

  void _handleTap() {
    if (widget.generating) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(
        Offset(box.size.width / 2, box.size.height / 2));
    widget.onTap(pos);
  }

  @override
  Widget build(BuildContext context) {
    final done  = widget.stars > 0;
    final color = done
        ? GemColors.success
        : widget.hasContent
            ? GemColors.polyglotColor
            : Colors.white.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: widget.nodeSize,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            key: _key,
            width:  widget.nodeSize,
            height: widget.nodeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? GemColors.success.withValues(alpha: 0.18)
                  : widget.hasContent
                      ? GemColors.polyglotColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: color, width: done ? 2.5 : 1.5),
              boxShadow: done
                  ? [
                      BoxShadow(
                          color: GemColors.success.withValues(alpha: 0.3),
                          blurRadius: 14)
                    ]
                  : widget.hasContent
                      ? [
                          BoxShadow(
                              color:
                                  GemColors.polyglotColor.withValues(alpha: 0.2),
                              blurRadius: 10)
                        ]
                      : null,
            ),
            child: widget.generating
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: GemColors.polyglotColor),
                  )
                : Center(
                    child: done
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_rounded,
                                size: 20, color: GemColors.success),
                            Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                    3,
                                    (i) => Icon(
                                          i < widget.stars
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          size: 9,
                                          color: i < widget.stars
                                              ? GemColors.warning
                                              : GemColors.success
                                                  .withValues(alpha: 0.3),
                                        ))),
                          ])
                        : Text(
                            '${widget.index}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.topic,
            style: TextStyle(
              fontSize: 9,
              color: done
                  ? GemColors.success.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.4),
              fontWeight: done ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
    );
  }
}

// LESSON SCREEN

class _LessonScreen extends StatefulWidget {
  final LangInfo  lang;
  final LangLesson lesson;
  final Future<void> Function(int stars, int xp) onComplete;

  const _LessonScreen(
      {required this.lang, required this.lesson, required this.onComplete});

  @override
  State<_LessonScreen> createState() => _LessonScreenState();
}

enum _Phase { learn, quiz, match, fillBlanks, done }

class _LessonScreenState extends State<_LessonScreen> {
  _Phase _phase = _Phase.learn;
  int _score = 0;
  int _total = 0;
  bool _completing = false;

  void _onLearnDone() => setState(() => _phase = _Phase.quiz);

  void _onQuizDone(int correct, int outOf) {
    _score += correct;
    _total += outOf;
    setState(() => _phase = _Phase.match);
  }

  void _onMatchDone(int correct, int outOf) {
    _score += correct;
    _total += outOf;
    setState(() => _phase = _Phase.fillBlanks);
  }

  void _onFillBlanksDone(int correct, int outOf) {
    _score += correct;
    _total += outOf;
    setState(() => _phase = _Phase.done);
  }

  Future<void> _finish() async {
    if (_completing) return;
    setState(() => _completing = true);
    final pct   = _total == 0 ? 100 : (_score / _total * 100).round();
    final stars = pct >= 90 ? 3 : pct >= 70 ? 2 : pct >= 50 ? 1 : 0;
    final xp    = stars * 15 + _score * 2;
    await widget.onComplete(stars, xp);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.lesson.title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _PhaseBar(phase: _phase),
          ),
        ),
        body: switch (_phase) {
          _Phase.learn => _LearnPhase(
              items:    widget.lesson.items,
              locale:   widget.lang.ttsLocale,
              langName: widget.lang.name,
              onDone:   _onLearnDone,
            ),
          _Phase.quiz => _McqPhase(
              items:  widget.lesson.items,
              onDone: _onQuizDone,
            ),
          _Phase.match => _MatchPhase(
              items:  widget.lesson.items,
              onDone: _onMatchDone,
            ),
          _Phase.fillBlanks => _FillBlanksPhase(
              items:    widget.lesson.items,
              langName: widget.lang.name,
              onDone:   _onFillBlanksDone,
            ),
          _Phase.done => _DoneScreen(
              score:      _score,
              total:      _total,
              onFinish:   _finish,
              completing: _completing,
            ),
        },
      ),
    );
  }
}

class _PhaseBar extends StatelessWidget {
  final _Phase phase;
  const _PhaseBar({required this.phase});

  @override
  Widget build(BuildContext context) {
    final v = switch (phase) {
      _Phase.learn      => 1 / 5,
      _Phase.quiz       => 2 / 5,
      _Phase.match      => 3 / 5,
      _Phase.fillBlanks => 4 / 5,
      _Phase.done       => 1.0,
    };
    return LinearProgressIndicator(
      value: v,
      minHeight: 3,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      valueColor: const AlwaysStoppedAnimation(GemColors.polyglotColor),
    );
  }
}

// PHASE 1: LEARN (romanization-first flashcard)

class _LearnPhase extends StatefulWidget {
  final List<LangItem> items;
  final String locale;
  final String langName;
  final VoidCallback onDone;

  const _LearnPhase({
    required this.items,
    required this.locale,
    required this.langName,
    required this.onDone,
  });

  @override
  State<_LearnPhase> createState() => _LearnPhaseState();
}

class _LearnPhaseState extends State<_LearnPhase> {
  int         _idx  = 0;
  FlutterTts? _tts;
  bool _ttsUnavailable = false;
  bool _speaking       = false;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (!_isDesktop) _tts = FlutterTts();
  }

  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_isDesktop || _tts == null || _speaking) return;
    setState(() => _speaking = true);
    final item = widget.items[_idx];
    try {
      final langOk = await _tts!.setLanguage(widget.locale);
      await _tts!.setSpeechRate(0.42);
      if (langOk == 1) {
        await _tts!.speak(item.text);
      } else {
        await _tts!.setLanguage('en-US');
        await _tts!.speak(item.romanized);
        if (mounted) setState(() => _ttsUnavailable = true);
      }
    } catch (_) {}
    if (mounted) setState(() => _speaking = false);
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_idx + 1 >= widget.items.length) {
      widget.onDone();
    } else {
      setState(() {
        _idx++;
        _ttsUnavailable = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item   = widget.items[_idx];
    final isLast = _idx + 1 >= widget.items.length;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          Text('${_idx + 1} / ${widget.items.length}',
              style: const TextStyle(
                  fontSize: 13, color: GemColors.textSecondary)),
          const Spacer(),
          const Text('Learn',
              style: TextStyle(
                  fontSize: 13,
                  color: GemColors.polyglotColor,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 4),
      LinearProgressIndicator(
        value: (_idx + 1) / widget.items.length,
        minHeight: 2,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        valueColor: const AlwaysStoppedAnimation(GemColors.polyglotColor),
      ),

      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Main card - romaji-first
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: GemColors.polyglotColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: GemColors.polyglotColor.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                // Romanization - big, beginner-friendly
                Text(
                  item.romanized.isEmpty ? item.text : item.romanized,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (item.romanized.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  // Native script as subscript-style pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: GemColors.polyglotColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.text,
                      style: TextStyle(
                        fontSize: 22,
                        color: GemColors.polyglotColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Speak button
                GestureDetector(
                  onTap: _isDesktop ? null : _speak,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: _speaking
                          ? GemColors.polyglotColor.withValues(alpha: 0.25)
                          : GemColors.polyglotColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: GemColors.polyglotColor.withValues(
                              alpha: _isDesktop ? 0.2 : 0.45)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _isDesktop
                            ? Icons.volume_off_rounded
                            : _speaking
                                ? Icons.volume_up_rounded
                                : Icons.volume_up_outlined,
                        size: 16,
                        color: GemColors.polyglotColor.withValues(
                            alpha: _isDesktop ? 0.4 : 1.0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isDesktop ? 'TTS unavailable' : 'Tap to listen',
                        style: TextStyle(
                          fontSize: 13,
                          color: GemColors.polyglotColor.withValues(
                              alpha: _isDesktop ? 0.4 : 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  ),
                ),
                if (_ttsUnavailable) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Playing romanized guide - install ${widget.langName} voice for native audio',
                    style: const TextStyle(
                        fontSize: 10, color: GemColors.warning),
                    textAlign: TextAlign.center,
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 16),

            // Meaning card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Meaning',
                    style: TextStyle(
                        fontSize: 11,
                        color: GemColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(item.meaning,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3)),
              ]),
            ),

            // Example
            if (item.example != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Example',
                      style: TextStyle(
                          fontSize: 10,
                          color: GemColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 5),
                  Text(item.example!,
                      style: TextStyle(
                          fontSize: 14,
                          color: GemColors.polyglotColor.withValues(alpha: 0.85),
                          fontStyle: FontStyle.italic,
                          height: 1.5)),
                  if (item.exampleMeaning != null) ...[
                    const SizedBox(height: 3),
                    Text(item.exampleMeaning!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4))),
                  ],
                ]),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GemColors.polyglotColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text(isLast ? 'Start Quiz ->' : 'Got it! ->',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// PHASE 2: MCQ QUIZ

class _McqPhase extends StatefulWidget {
  final List<LangItem> items;
  final void Function(int correct, int total) onDone;

  const _McqPhase({required this.items, required this.onDone});

  @override
  State<_McqPhase> createState() => _McqPhaseState();
}

class _McqPhaseState extends State<_McqPhase> {
  late final List<_McqQ> _questions;
  int  _idx     = 0;
  int  _correct = 0;
  int? _tapped;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions();
  }

  List<_McqQ> _buildQuestions() {
    final rng = Random();
    return widget.items.map((item) {
      final wrong = widget.items.where((x) => x != item).toList()..shuffle(rng);
      final opts  = [item, ...wrong.take(3)]..shuffle(rng);
      return _McqQ(
        question:   'What does "${item.romanized.isNotEmpty ? item.romanized : item.text}" mean?',
        native:     item.text,
        romanized:  item.romanized,
        options:    opts.map((o) => o.meaning).toList(),
        correctIdx: opts.indexOf(item),
      );
    }).toList();
  }

  void _select(int i) {
    if (_tapped != null) return;
    HapticFeedback.lightImpact();
    if (i == _questions[_idx].correctIdx) _correct++;
    setState(() => _tapped = i);
  }

  void _next() {
    if (_idx + 1 >= _questions.length) {
      widget.onDone(_correct, _questions.length);
    } else {
      setState(() {
        _idx++;
        _tapped = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_idx];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('${_idx + 1} / ${_questions.length}',
              style: const TextStyle(
                  fontSize: 13, color: GemColors.textSecondary)),
          const Spacer(),
          const Text('Quiz',
              style: TextStyle(fontSize: 13, color: GemColors.polyglotColor)),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _idx / _questions.length,
          minHeight: 3,
          backgroundColor: Colors.white.withValues(alpha: 0.07),
          valueColor: const AlwaysStoppedAnimation(GemColors.polyglotColor),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
            Text(q.romanized.isEmpty ? q.native : q.romanized,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
                textAlign: TextAlign.center),
            if (q.romanized.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(q.native,
                  style: TextStyle(
                      fontSize: 16,
                      color: GemColors.polyglotColor.withValues(alpha: 0.75)),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 4),
            Text('What does this mean?',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45))),
          ]),
        ),
        const SizedBox(height: 14),
        ...List.generate(q.options.length, (i) {
          final answered   = _tapped != null;
          final isCorrect  = i == q.correctIdx;
          final isSelected = _tapped == i;
          final Color bg, border, fg;
          if (!answered) {
            bg     = Colors.white.withValues(alpha: 0.05);
            border = Colors.white.withValues(alpha: 0.1);
            fg     = Colors.white;
          } else if (isCorrect) {
            bg     = GemColors.success.withValues(alpha: 0.1);
            border = GemColors.success;
            fg     = GemColors.success;
          } else if (isSelected) {
            bg     = GemColors.danger.withValues(alpha: 0.1);
            border = GemColors.danger;
            fg     = GemColors.danger;
          } else {
            bg     = Colors.white.withValues(alpha: 0.02);
            border = Colors.white.withValues(alpha: 0.05);
            fg     = Colors.white.withValues(alpha: 0.3);
          }
          return GestureDetector(
            onTap: answered ? null : () => _select(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: border,
                    width:
                        answered && (isCorrect || isSelected) ? 1.5 : 1),
              ),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fg.withValues(alpha: 0.15)),
                  child: Center(
                      child: answered && isCorrect
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: GemColors.success)
                          : answered && isSelected
                              ? const Icon(Icons.close_rounded,
                                  size: 14, color: GemColors.danger)
                              : Text(['A', 'B', 'C', 'D'][i],
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: GemColors.polyglotColor))),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(q.options[i],
                        style: TextStyle(fontSize: 14, color: fg))),
              ]),
            ),
          );
        }),
        if (_tapped != null) ...[
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  GemColors.polyglotColor.withValues(alpha: 0.18),
              foregroundColor: GemColors.polyglotColor,
              side: BorderSide(
                  color: GemColors.polyglotColor.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _idx + 1 >= _questions.length
                  ? 'Matching Game ->'
                  : 'Next ->',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ]),
    );
  }
}

class _McqQ {
  final String question;
  final String native;
  final String romanized;
  final List<String> options;
  final int correctIdx;
  const _McqQ({
    required this.question,
    required this.native,
    required this.romanized,
    required this.options,
    required this.correctIdx,
  });
}

// PHASE 3: MATCHING GAME

class _MatchPhase extends StatefulWidget {
  final List<LangItem> items;
  final void Function(int correct, int total) onDone;

  const _MatchPhase({required this.items, required this.onDone});

  @override
  State<_MatchPhase> createState() => _MatchPhaseState();
}

class _MatchPhaseState extends State<_MatchPhase> {
  late List<_MatchPair> _pairs;
  int     _round    = 0;
  int     _correct  = 0;
  int     _total    = 0;
  String? _selWord;
  String? _selMean;
  Set<String> _matched  = {};
  bool    _checking = false;

  static const _pairSize = 4;

  @override
  void initState() {
    super.initState();
    _buildRound();
  }

  void _buildRound() {
    final start = _round * _pairSize;
    final slice = widget.items.skip(start).take(_pairSize).toList();
    if (slice.isEmpty) {
      _finish();
      return;
    }
    _pairs = slice
        .map((i) => _MatchPair(
              word:    i.romanized.isNotEmpty ? i.romanized : i.text,
              meaning: i.meaning,
              native:  i.text,
            ))
        .toList();
    _total += slice.length;
    setState(() {});
  }

  void _tapWord(String word) {
    if (_matched.contains(word) || _checking) return;
    setState(() => _selWord = word);
    _checkMatch();
  }

  void _tapMean(String mean) {
    if (_checking) return;
    final alreadyMatched = _matched.any(
        (w) => _pairs.any((p) => p.word == w && p.meaning == mean));
    if (alreadyMatched) return;
    setState(() => _selMean = mean);
    _checkMatch();
  }

  Future<void> _checkMatch() async {
    if (_selWord == null || _selMean == null) return;
    _checking = true;
    final pair = _pairs.firstWhere(
      (p) => p.word == _selWord,
      orElse: () => const _MatchPair(word: '', meaning: '', native: ''),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (pair.meaning == _selMean) {
      HapticFeedback.mediumImpact();
      _matched.add(_selWord!);
      _correct++;
    } else {
      HapticFeedback.vibrate();
    }
    setState(() {
      _selWord  = null;
      _selMean  = null;
      _checking = false;
    });
    if (_matched.length >= _pairs.length) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final nextStart = (_round + 1) * _pairSize;
      if (nextStart >= widget.items.length) {
        _finish();
      } else {
        setState(() {
          _round++;
          _matched = {};
        });
        _buildRound();
      }
    }
  }

  void _finish() => widget.onDone(_correct, _total);

  @override
  Widget build(BuildContext context) {
    final words = _pairs.map((p) => p.word).toList()
      ..shuffle(Random(42 + _round));
    final means = _pairs.map((p) => p.meaning).toList()
      ..shuffle(Random(99 + _round));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        const Text('Match the pairs',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text('Round ${_round + 1} - Tap a word then its meaning',
            style:
                TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child:
                  Column(children: words.map((w) => _tile(w, true)).toList())),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  children: means.map((m) => _tile(m, false)).toList())),
        ]),
      ]),
    );
  }

  Widget _tile(String label, bool isWord) {
    final matched = isWord
        ? _matched.contains(label)
        : _matched.any(
            (w) => _pairs.any((p) => p.word == w && p.meaning == label));
    final selected = isWord ? _selWord == label : _selMean == label;

    return GestureDetector(
      onTap: isWord ? () => _tapWord(label) : () => _tapMean(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: matched
              ? GemColors.success.withValues(alpha: 0.1)
              : selected
                  ? GemColors.polyglotColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: matched
                ? GemColors.success.withValues(alpha: 0.5)
                : selected
                    ? GemColors.polyglotColor.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: matched
                    ? GemColors.success
                    : selected
                        ? GemColors.polyglotColor
                        : Colors.white,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center),
          if (isWord) ...(() {
            final pair = _pairs.firstWhere((p) => p.word == label,
                orElse: () =>
                    const _MatchPair(word: '', meaning: '', native: ''));
            if (pair.native.isNotEmpty && pair.native != label) {
              return [
                const SizedBox(height: 2),
                Text(pair.native,
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            GemColors.polyglotColor.withValues(alpha: 0.55)),
                    textAlign: TextAlign.center),
              ];
            }
            return <Widget>[];
          })(),
        ]),
      ),
    );
  }
}

class _MatchPair {
  final String word;
  final String meaning;
  final String native;
  const _MatchPair(
      {required this.word, required this.meaning, required this.native});
}

// PHASE 4: FILL IN THE BLANKS (tile pool)

class _FillBlanksPhase extends StatefulWidget {
  final List<LangItem> items;
  final String langName;
  final void Function(int correct, int total) onDone;

  const _FillBlanksPhase(
      {required this.items, required this.langName, required this.onDone});

  @override
  State<_FillBlanksPhase> createState() => _FillBlanksPhaseState();
}

class _FillBlanksPhaseState extends State<_FillBlanksPhase> {
  late final List<_FillQ> _questions;
  int  _idx      = 0;
  int  _correct  = 0;
  late List<String?> _slots;
  late List<String>  _pool;
  bool _checked   = false;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions();
    if (_questions.isNotEmpty) _resetSlots();
    if (_questions.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onDone(0, 0));
    }
  }

  List<_FillQ> _buildQuestions() {
    final rng = Random();
    final qs  = <_FillQ>[];
    final romanizedMap = {for (final i in widget.items) i.text: i.romanized};
    for (final item in widget.items) {
      final wrong = widget.items.where((x) => x != item).toList()
        ..shuffle(rng);

      List<String> blanks;
      String template;
      if (item.example != null && item.example!.contains(item.text)) {
        template = item.example!.replaceFirst(item.text, '{{0}}');
        blanks   = [item.text];
      } else {
        template =
            "The ${widget.langName} word for '${item.meaning}' is {{0}}";
        blanks = [item.text];
      }

      final distractors = wrong
          .take(min(3, wrong.length))
          .map((w) => w.text)
          .toList();
      final pool = [blanks[0], ...distractors]..shuffle(rng);

      qs.add(_FillQ(
        template:      template,
        hint:          item.meaning,
        nativeHint:    item.text,
        romanizedHint: item.romanized,
        blanks:        blanks,
        pool:          pool,
        poolRomaji:    romanizedMap,
      ));
    }
    return qs;
  }

  void _resetSlots() {
    final q  = _questions[_idx];
    _slots   = List<String?>.filled(q.blanks.length, null);
    _pool    = List<String>.from(q.pool);
    _checked = false;
    _isCorrect = false;
  }

  void _tapPool(String word) {
    if (_checked) return;
    final emptySlot = _slots.indexWhere((s) => s == null);
    if (emptySlot == -1) return;
    setState(() {
      _slots[emptySlot] = word;
      _pool.remove(word);
    });
  }

  void _tapSlot(int slotIdx) {
    if (_checked || _slots[slotIdx] == null) return;
    setState(() {
      _pool.add(_slots[slotIdx]!);
      _slots[slotIdx] = null;
    });
  }

  void _check() {
    if (_slots.any((s) => s == null)) return;
    final q  = _questions[_idx];
    var ok   = true;
    for (int i = 0; i < q.blanks.length; i++) {
      if (_slots[i]?.toLowerCase() != q.blanks[i].toLowerCase()) {
        ok = false;
        break;
      }
    }
    if (ok) _correct++;
    HapticFeedback.lightImpact();
    setState(() {
      _checked   = true;
      _isCorrect = ok;
    });
  }

  void _next() {
    if (_idx + 1 >= _questions.length) {
      widget.onDone(_correct, _questions.length);
    } else {
      setState(() => _idx++);
      _resetSlots();
    }
  }

  Widget _buildSentence(_FillQ q) {
    final parts            = q.template.split(RegExp(r'\{\{(\d+)\}\}'));
    final blanksInTemplate =
        RegExp(r'\{\{(\d+)\}\}').allMatches(q.template).toList();
    final spans = <InlineSpan>[];
    int blankIdx = 0;
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(
          text:  parts[i],
          style: const TextStyle(
              fontSize: 18, color: Colors.white, height: 1.5),
        ));
      }
      if (i < blanksInTemplate.length) {
        final slotI = blankIdx;
        final filled = _slots[slotI];
        final borderColor = !_checked
            ? (filled != null
                ? GemColors.polyglotColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.3))
            : (_isCorrect ? GemColors.success : GemColors.danger);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _tapSlot(slotI),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              constraints: const BoxConstraints(minWidth: 60),
              decoration: BoxDecoration(
                color: filled != null
                    ? (_checked
                        ? (_isCorrect
                            ? GemColors.success.withValues(alpha: 0.1)
                            : GemColors.danger.withValues(alpha: 0.1))
                        : GemColors.polyglotColor.withValues(alpha: 0.12))
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Text(
                filled ?? '  ___  ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: filled != null
                      ? (_checked
                          ? (_isCorrect
                              ? GemColors.success
                              : GemColors.danger)
                          : GemColors.polyglotColor)
                      : Colors.white.withValues(alpha: 0.3),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ));
        blankIdx++;
      }
    }
    return RichText(
        textAlign: TextAlign.center, text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Center(
          child:
              CircularProgressIndicator(color: GemColors.polyglotColor));
    }

    final q         = _questions[_idx];
    final allFilled = _slots.every((s) => s != null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        Row(children: [
          Text('${_idx + 1} / ${_questions.length}',
              style: const TextStyle(
                  fontSize: 13, color: GemColors.textSecondary)),
          const Spacer(),
          const Text('Fill the Blank',
              style:
                  TextStyle(fontSize: 13, color: GemColors.polyglotColor)),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _idx / _questions.length,
          minHeight: 3,
          backgroundColor: Colors.white.withValues(alpha: 0.07),
          valueColor:
              const AlwaysStoppedAnimation(GemColors.polyglotColor),
        ),
        const SizedBox(height: 20),

        GlassCard(
          child: Column(children: [
            _buildSentence(q),
            const SizedBox(height: 10),
            Text(q.nativeHint,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: GemColors.polyglotColor.withValues(alpha: 0.8))),
            const SizedBox(height: 2),
            Text(q.hint,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic)),
          ]),
        ),

        const SizedBox(height: 20),
        Text('Word bank - tap to place:',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _pool.map((word) {
            final romaji = q.poolRomaji[word] ?? '';
            return GestureDetector(
              onTap: _checked ? null : () => _tapPool(word),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: GemColors.polyglotColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: GemColors.polyglotColor.withValues(alpha: 0.35),
                      width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(word,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: GemColors.polyglotColor)),
                    if (romaji.isNotEmpty)
                      Text(romaji,
                          style: TextStyle(
                              fontSize: 10,
                              color: GemColors.polyglotColor
                                  .withValues(alpha: 0.6))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        if (!_checked) ...[
          ElevatedButton(
            onPressed: allFilled ? _check : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: allFilled
                  ? GemColors.polyglotColor
                  : Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: Text(
              allFilled ? 'Check Answer' : 'Fill all blanks first',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ] else ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (_isCorrect ? GemColors.success : GemColors.danger)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      (_isCorrect ? GemColors.success : GemColors.danger)
                          .withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              Icon(
                _isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: _isCorrect ? GemColors.success : GemColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isCorrect ? 'Correct!' : 'Answer: ${q.blanks.join(", ")}',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        _isCorrect ? GemColors.success : GemColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  GemColors.polyglotColor.withValues(alpha: 0.18),
              foregroundColor: GemColors.polyglotColor,
              side: BorderSide(
                  color: GemColors.polyglotColor.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _idx + 1 >= _questions.length
                  ? 'Finish ->'
                  : 'Next ->',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ]),
    );
  }
}

class _FillQ {
  final String template;
  final String hint;
  final String nativeHint;
  final String romanizedHint;
  final List<String> blanks;
  final List<String> pool;
  // maps each native word in pool to its romanized reading, shown as a hint under the chip
  final Map<String, String> poolRomaji;

  const _FillQ({
    required this.template,
    required this.hint,
    required this.nativeHint,
    required this.romanizedHint,
    required this.blanks,
    required this.pool,
    required this.poolRomaji,
  });
}

// DONE SCREEN

class _DoneScreen extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onFinish;
  final bool completing;

  const _DoneScreen({
    required this.score,
    required this.total,
    required this.onFinish,
    required this.completing,
  });

  @override
  Widget build(BuildContext context) {
    final pct   = total == 0 ? 100 : (score / total * 100).round();
    final stars = pct >= 90 ? 3 : pct >= 70 ? 2 : pct >= 50 ? 1 : 0;
    final xp    = stars * 15 + score * 2;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(stars == 3 ? '🏆' : stars >= 2 ? '⭐⭐' : '⭐',
              style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('Lesson Complete!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                  3,
                  (i) => Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 32,
                        color: i < stars
                            ? GemColors.warning
                            : Colors.white.withValues(alpha: 0.2),
                      ))),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              color: GemColors.polyglotColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: GemColors.polyglotColor.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Text('$score / $total',
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: GemColors.polyglotColor)),
              Text('$pct% correct',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 8),
              Text('+$xp XP',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GemColors.warning)),
            ]),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: completing ? null : onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    GemColors.polyglotColor.withValues(alpha: 0.2),
                foregroundColor: GemColors.polyglotColor,
                side: BorderSide(
                    color: GemColors.polyglotColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: completing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: GemColors.polyglotColor),
                    )
                  : const Text('Finish',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

