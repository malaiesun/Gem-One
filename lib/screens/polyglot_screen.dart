import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/gemma_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

class _Lesson {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String topic;

  const _Lesson({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.topic,
  });
}

const _lessons = [
  _Lesson(id: 'greet',   title: 'Greetings',     icon: Icons.waving_hand_rounded,     color: Color(0xFF6BCFFF), topic: 'hello, goodbye, thank you, please, sorry'),
  _Lesson(id: 'numbers', title: 'Numbers 1-10',   icon: Icons.numbers_rounded,          color: Color(0xFF9B8BFF), topic: 'one, two, three, four, five'),
  _Lesson(id: 'colors',  title: 'Colors',         icon: Icons.palette_rounded,          color: Color(0xFFFF9E64), topic: 'red, blue, green, white, black'),
  _Lesson(id: 'food',    title: 'Food & Drink',   icon: Icons.restaurant_rounded,       color: Color(0xFF6BFFB8), topic: 'water, rice, bread, fruit, tea'),
  _Lesson(id: 'travel',  title: 'Getting Around', icon: Icons.directions_rounded,       color: Color(0xFFFF6B8A), topic: 'where, bus, road, far, near'),
  _Lesson(id: 'body',    title: 'Body & Health',  icon: Icons.favorite_rounded,         color: Color(0xFFFFD93D), topic: 'head, hand, eye, pain, doctor'),
  _Lesson(id: 'family',  title: 'Family',         icon: Icons.family_restroom_rounded,  color: Color(0xFFB48EFF), topic: 'mother, father, child, sister, brother'),
];

const _languages = [
  'Tamil', 'Hindi', 'Spanish', 'French', 'Mandarin',
  'Arabic', 'Japanese', 'German', 'Portuguese', 'Swahili',
];

const _ttsLangCodes = {
  'Tamil': 'ta-IN',   'Hindi': 'hi-IN',    'Spanish': 'es-ES',
  'French': 'fr-FR',  'Mandarin': 'zh-CN', 'Arabic': 'ar-SA',
  'Japanese': 'ja-JP','German': 'de-DE',   'Portuguese': 'pt-BR',
  'Swahili': 'sw-TZ', 'English': 'en-US',
};

class PolyglotScreen extends StatefulWidget {
  const PolyglotScreen({super.key});

  @override
  State<PolyglotScreen> createState() => _PolyglotScreenState();
}

class _PolyglotScreenState extends State<PolyglotScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  String _learnLang = 'Tamil';
  Map<String, int> _progress = {};

  String _srcLang = 'English';
  String _dstLang = 'Tamil';
  final _srcCtrl = TextEditingController();
  String _result = '';
  bool _translating = false;

  // flutter_tts crashes on Windows/Linux; desktop is excluded at startup rather than at call sites.
  static final _ttsAvailable = !Platform.isWindows && !Platform.isLinux;
  FlutterTts? _tts;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadProgress();
    if (_ttsAvailable) _tts = FlutterTts();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _srcCtrl.dispose();
    _tts?.stop();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, int>{};
    for (final lang in _languages) {
      map[lang] = prefs.getInt('polyglot_done_$lang') ?? -1;
    }
    if (mounted) setState(() => _progress = map);
  }

  Future<void> _markDone(String lang, int lessonIdx) async {
    final current = _progress[lang] ?? -1;
    // Only advance; never allow progress to regress if the user replays an earlier lesson.
    if (lessonIdx > current) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('polyglot_done_$lang', lessonIdx);
      if (mounted) setState(() => _progress[lang] = lessonIdx);
    }
  }

  void _openLesson(int idx) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _LessonScreen(
          language: _learnLang,
          lesson: _lessons[idx],
          levelIndex: idx,
          onComplete: () => _markDone(_learnLang, idx),
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutQuint)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    ).then((_) => _loadProgress());
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
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: GemColors.polyglotColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GemColors.polyglotColor.withValues(alpha: 0.35), width: 0.8),
              ),
              child: const Icon(Icons.translate_rounded, size: 15, color: GemColors.polyglotColor),
            ),
            const SizedBox(width: 10),
            const Text('Polyglot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: GemColors.polyglotColor,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            labelColor: GemColors.polyglotColor,
            unselectedLabelColor: GemColors.textSecondary,
            tabs: const [Tab(text: 'Journey'), Tab(text: 'Translate')],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [_buildJourneyTab(), _buildTranslateTab()],
        ),
      ),
    );
  }

  Widget _buildJourneyTab() {
    return LayoutBuilder(builder: (context, box) {
      final isWide = box.maxWidth > 600;
      return isWide
          ? Row(children: [
              SizedBox(width: 220, child: _buildLanguageSidebar()),
              const VerticalDivider(width: 1, color: Colors.white10),
              Expanded(child: _buildSkillMap()),
            ])
          : Column(children: [
              _buildLanguageBar(),
              Expanded(child: _buildSkillMap()),
            ]);
    });
  }

  Widget _buildLanguageBar() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _langChip(_languages[i]),
      ),
    );
  }

  Widget _buildLanguageSidebar() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _languages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final lang = _languages[i];
        final done = (_progress[lang] ?? -1) + 1;
        final sel = lang == _learnLang;
        return GestureDetector(
          onTap: () => setState(() => _learnLang = lang),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: sel
                  ? GemColors.polyglotColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? GemColors.polyglotColor.withValues(alpha: 0.4) : Colors.transparent),
            ),
            child: Row(children: [
              Expanded(child: Text(lang, style: TextStyle(
                fontSize: 14,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                color: sel ? GemColors.polyglotColor : Colors.white.withValues(alpha: 0.8),
              ))),
              if (done > 0) Text('$done/${_lessons.length}',
                style: const TextStyle(fontSize: 11, color: GemColors.success)),
            ]),
          ),
        );
      },
    );
  }

  Widget _langChip(String lang) {
    final sel = lang == _learnLang;
    return GestureDetector(
      onTap: () => setState(() => _learnLang = lang),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel
              ? GemColors.polyglotColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel
                  ? GemColors.polyglotColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(lang, style: TextStyle(
          fontSize: 13,
          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
          color: sel ? GemColors.polyglotColor : Colors.white.withValues(alpha: 0.7),
        )),
      ),
    );
  }

  Widget _buildSkillMap() {
    final done = _progress[_learnLang] ?? -1;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      itemCount: _lessons.length,
      itemBuilder: (_, i) {
        final lesson = _lessons[i];
        final completed = i <= done;
        final unlocked  = i <= done + 1;
        final isCurrent = i == done + 1;
        return _SkillNode(
          lesson: lesson,
          completed: completed,
          unlocked: unlocked,
          isCurrent: isCurrent,
          showLine: i < _lessons.length - 1,
          lineDone: completed,
          onTap: unlocked ? () => _openLesson(i) : null,
        );
      },
    );
  }

  static const _translateLangs = [
    'English', 'Tamil', 'Hindi', 'Spanish', 'French',
    'Mandarin', 'Arabic', 'Japanese', 'German', 'Portuguese', 'Swahili',
  ];

  Widget _buildTranslateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: _langDropdown(_srcLang, (v) => setState(() => _srcLang = v!))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                onTap: () => setState(() {
                  final t = _srcLang; _srcLang = _dstLang; _dstLang = t;
                  final r = _srcCtrl.text; _srcCtrl.text = _result; _result = r;
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GemColors.polyglotColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: GemColors.polyglotColor.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: GemColors.polyglotColor, size: 18),
                ),
              ),
            ),
            Expanded(child: _langDropdown(_dstLang, (v) => setState(() => _dstLang = v!))),
          ]),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _srcCtrl,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(fontSize: 15, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter text…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.polyglotColor.withValues(alpha: 0.2),
              foregroundColor: GemColors.polyglotColor,
              side: BorderSide(color: GemColors.polyglotColor.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _translating ? null : _doTranslate,
            child: _translating
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Translate', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SelectableText(
                    _result,
                    style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.6),
                  )),
                  if (_ttsAvailable) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        await _tts?.setLanguage(_ttsLangCodes[_dstLang] ?? 'en-US');
                        await _tts?.setSpeechRate(0.45);
                        await _tts?.speak(_result);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GemColors.polyglotColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: GemColors.polyglotColor.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.volume_up_rounded, size: 18, color: GemColors.polyglotColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _langDropdown(String value, ValueChanged<String?> onChanged) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: GemColors.surface,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GemColors.textSecondary, size: 18),
          items: _translateLangs.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _doTranslate() async {
    final text = _srcCtrl.text.trim();
    if (text.isEmpty) return;
    final service = GemmaServiceProvider.of(context);
    setState(() { _translating = true; _result = ''; });
    try {
      final reply = await service.quickReply(
        'Translate from $_srcLang to $_dstLang. '
        'Output ONLY the translated text, no explanations:\n$text',
      );
      if (mounted) setState(() => _result = reply);
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }
}

// SKILL MAP NODE

class _SkillNode extends StatelessWidget {
  final _Lesson lesson;
  final bool completed;
  final bool unlocked;
  final bool isCurrent;
  final bool showLine;
  final bool lineDone;
  final VoidCallback? onTap;

  const _SkillNode({
    required this.lesson,
    required this.completed,
    required this.unlocked,
    required this.isCurrent,
    required this.showLine,
    required this.lineDone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = completed
        ? GemColors.success
        : unlocked
            ? lesson.color
            : Colors.white.withValues(alpha: 0.18);

    return Column(children: [
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: unlocked
                ? col.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: completed
                  ? GemColors.success.withValues(alpha: 0.45)
                  : isCurrent
                      ? lesson.color.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.07),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: col.withValues(alpha: 0.3)),
              ),
              child: Icon(
                completed ? Icons.check_rounded : lesson.icon,
                size: 22,
                color: col,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title, style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: unlocked ? Colors.white : Colors.white.withValues(alpha: 0.3),
                )),
                const SizedBox(height: 3),
                Text(
                  completed ? 'Completed ✓' : isCurrent ? 'Tap to start' : 'Locked',
                  style: TextStyle(
                    fontSize: 12,
                    color: completed
                        ? GemColors.success
                        : isCurrent
                            ? lesson.color
                            : Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ],
            )),
            if (!unlocked)
              Icon(Icons.lock_outline_rounded, size: 16, color: Colors.white.withValues(alpha: 0.2))
            else if (isCurrent)
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: lesson.color.withValues(alpha: 0.7)),
          ]),
        ),
      ),
      if (showLine)
        Container(
          width: 2, height: 14,
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: lineDone
                ? GemColors.success.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
    ]);
  }
}

// LESSON SCREEN - flashcard + quiz

enum _LessonPhase { intro, loading, word, quiz, result, complete }

class _LessonScreen extends StatefulWidget {
  final String language;
  final _Lesson lesson;
  final int levelIndex;
  final VoidCallback onComplete;

  const _LessonScreen({
    required this.language,
    required this.lesson,
    required this.levelIndex,
    required this.onComplete,
  });

  @override
  State<_LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<_LessonScreen>
    with SingleTickerProviderStateMixin {
  _LessonPhase _phase = _LessonPhase.intro;
  int _wordIdx = 0;
  int _score = 0;
  static const _total = 5; // 5 words per lesson - a product decision, not derived from data

  String _word = '';
  String _pronunciation = '';
  String _meaning = '';
  String _example = '';
  String _quizQ = '';
  List<String> _options = [];
  int _correctIdx = 0;
  int? _tapped;
  String _statusMsg = '';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.value = 1.0; // show intro immediately
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWord() async {
    if (!mounted) return;
    setState(() {
      _phase = _LessonPhase.loading;
      _statusMsg = 'Loading word ${_wordIdx + 1} of $_total…';
    });

    final service = GemmaServiceProvider.of(context);
    final topics = widget.lesson.topic.split(',').map((s) => s.trim()).toList();
    final focus = _wordIdx < topics.length ? topics[_wordIdx] : topics.last;

    final prompt =
        'You are a language teacher. Teach the ${widget.language} translation for: "$focus".\n'
        'Reply with EXACTLY these 4 lines and nothing else:\n'
        'WORD: [the ${widget.language} word or phrase]\n'
        'PRON: [pronunciation in simple English phonetics, e.g. "oh-LAH"]\n'
        'MEAN: [English meaning in 2-5 words]\n'
        'EXAM: [short example sentence in ${widget.language}] - [English translation]';

    try {
      final reply = await service.quickReply(prompt);
      _word = '';
      _pronunciation = '';
      _meaning = '';
      _example = '';
      for (final raw in reply.split('\n')) {
        final line = raw.trim();
        if (line.startsWith('WORD:')) {
          _word = line.substring(5).trim();
        } else if (line.startsWith('PRON:')) {
          _pronunciation = line.substring(5).trim();
        } else if (line.startsWith('MEAN:')) {
          _meaning = line.substring(5).trim();
        } else if (line.startsWith('EXAM:')) {
          _example = line.substring(5).trim();
        }
      }
      if (_word.isEmpty) _word = reply.split('\n').first.trim();
      if (mounted) {
        _animCtrl.forward(from: 0);
        setState(() => _phase = _LessonPhase.word);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _LessonPhase.intro);
    }
  }

  Future<void> _loadQuiz() async {
    if (!mounted) return;
    setState(() {
      _phase = _LessonPhase.loading;
      _statusMsg = 'Preparing quiz…';
      _tapped = null;
    });

    final service = GemmaServiceProvider.of(context);

    final prompt =
        'For the ${widget.language} word "$_word" (English meaning: "$_meaning"), '
        'write exactly 3 different plausible but WRONG English translation options.\n'
        'Reply with EXACTLY 3 lines:\n'
        'W1: [wrong option]\n'
        'W2: [wrong option]\n'
        'W3: [wrong option]';

    try {
      final reply = await service.quickReply(prompt);
      final wrongs = <String>[];
      for (final raw in reply.split('\n')) {
        final line = raw.trim();
        if (line.startsWith('W1:')) {
          wrongs.add(line.substring(3).trim());
        } else if (line.startsWith('W2:')) {
          wrongs.add(line.substring(3).trim());
        } else if (line.startsWith('W3:')) {
          wrongs.add(line.substring(3).trim());
        }
      }
      while (wrongs.length < 3) {
        wrongs.add('None of the above');
      }

      final opts = [_meaning, ...wrongs.take(3)];
      opts.shuffle();
      _options = opts;
      _correctIdx = _options.indexOf(_meaning);
      // indexOf should never return -1 since _meaning was just added, but guard
      // against floating-point or string normalisation differences from the model.
      if (_correctIdx < 0) {
        _correctIdx = 0;
        _options[0] = _meaning;
      }
      _quizQ = 'What is the English meaning of "$_word"?';

      if (mounted) {
        _animCtrl.forward(from: 0);
        setState(() => _phase = _LessonPhase.quiz);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _LessonPhase.word);
    }
  }

  void _selectAnswer(int idx) {
    if (_tapped != null) return;
    if (idx == _correctIdx) _score++;
    setState(() {
      _tapped = idx;
      _phase = _LessonPhase.result;
    });
  }

  void _next() {
    if (_wordIdx + 1 >= _total) {
      widget.onComplete();
      setState(() => _phase = _LessonPhase.complete);
    } else {
      _wordIdx++;
      _loadWord();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.lesson.color;
    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(color),
        body: Column(
          children: [
            _buildProgressBar(color),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildBody(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(Color color) {
    return AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.language} · ${widget.lesson.title}',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          if (_phase != _LessonPhase.intro && _phase != _LessonPhase.complete)
            Text(
              'Word ${_wordIdx + 1} of $_total  ·  Score $_score/$_total',
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Color color) {
    if (_phase == _LessonPhase.intro || _phase == _LessonPhase.complete) {
      return const SizedBox.shrink();
    }
    final progress =
        (_wordIdx + (_phase == _LessonPhase.result ? 1.0 : 0.5)) / _total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }

  Widget _buildBody(Color color) {
    return switch (_phase) {
      _LessonPhase.intro    => _buildIntro(color),
      _LessonPhase.loading  => _buildLoading(),
      _LessonPhase.word     => _buildWordCard(color),
      _LessonPhase.quiz     => _buildQuizCard(color, answered: false),
      _LessonPhase.result   => _buildQuizCard(color, answered: true),
      _LessonPhase.complete => _buildComplete(color),
    };
  }

  Widget _buildIntro(Color color) {
    final service = GemmaServiceProvider.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(widget.lesson.icon, size: 34, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              widget.lesson.title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.language} · 5 words · 1 quiz per word',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Text(
                widget.lesson.topic,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: color.withValues(alpha: 0.9),
                    height: 1.5),
              ),
            ),
            const SizedBox(height: 40),
            if (!service.isReady)
              Text('Waiting for AI model…',
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.4)))
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.2),
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _loadWord,
                  child: const Text('Begin Lesson',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              color: GemColors.accent, strokeWidth: 2),
          const SizedBox(height: 16),
          Text(_statusMsg,
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildWordCard(Color color) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Text(
                  _word,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_pronunciation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '/ $_pronunciation /',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                    width: 40, height: 1, color: color.withValues(alpha: 0.25)),
                const SizedBox(height: 18),
                Text(
                  _meaning,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (_example.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Example',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.8),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(_example,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white, height: 1.6)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.2),
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _loadQuiz,
              child: const Text('Quiz Me →',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(Color color, {required bool answered}) {
    final correct = _tapped == _correctIdx;
    const letters = ['A', 'B', 'C', 'D'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              Icon(Icons.quiz_rounded, size: 24, color: color.withValues(alpha: 0.8)),
              const SizedBox(height: 12),
              Text(_quizQ,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.4),
                  textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: 20),

          // Options
          for (var i = 0; i < _options.length; i++) ...[
            _buildOption(i, letters[i], color, answered),
            const SizedBox(height: 10),
          ],

          // Feedback banner
          if (answered) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: (correct ? GemColors.success : GemColors.danger)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: (correct ? GemColors.success : GemColors.danger)
                        .withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(
                  correct
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: correct ? GemColors.success : GemColors.danger,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  correct
                      ? 'Correct! "$_word" = "$_meaning".'
                      : 'Not quite - "$_word" means "$_meaning".',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: correct ? GemColors.success : GemColors.danger,
                  ),
                )),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.2),
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _next,
                child: Text(
                  _wordIdx + 1 >= _total
                      ? 'Finish Lesson  🎉'
                      : 'Next Word  →',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(int i, String letter, Color color, bool answered) {
    final isSelected = _tapped == i;
    final isCorrect  = i == _correctIdx;

    final Color borderColor;
    final Color bgColor;
    final Color textColor;

    if (!answered) {
      borderColor = color.withValues(alpha: 0.3);
      bgColor     = color.withValues(alpha: 0.06);
      textColor   = Colors.white;
    } else if (isCorrect) {
      borderColor = GemColors.success;
      bgColor     = GemColors.success.withValues(alpha: 0.1);
      textColor   = GemColors.success;
    } else if (isSelected) {
      borderColor = GemColors.danger;
      bgColor     = GemColors.danger.withValues(alpha: 0.1);
      textColor   = GemColors.danger;
    } else {
      borderColor = Colors.white.withValues(alpha: 0.08);
      bgColor     = Colors.white.withValues(alpha: 0.02);
      textColor   = Colors.white.withValues(alpha: 0.35);
    }

    return GestureDetector(
      onTap: answered ? null : () => _selectAnswer(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: borderColor,
              width: answered && (isCorrect || isSelected) ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: answered && (isCorrect || isSelected)
                  ? (isCorrect ? GemColors.success : GemColors.danger)
                      .withValues(alpha: 0.2)
                  : color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: answered && isCorrect
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: GemColors.success)
                  : answered && isSelected
                      ? const Icon(Icons.close_rounded,
                          size: 15, color: GemColors.danger)
                      : Text(letter,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(
            _options[i],
            style: TextStyle(
              fontSize: 14,
              fontWeight: answered && isCorrect
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: textColor,
            ),
          )),
        ]),
      ),
    );
  }

  Widget _buildComplete(Color color) {
    final pct = (_score / _total * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            const Text('Lesson Complete!',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              '${widget.lesson.title} · ${widget.language}',
              style: TextStyle(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 28),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Text('$_score / $_total',
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 4),
                Text('$pct% correct',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5))),
              ]),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.2),
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Journey',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
