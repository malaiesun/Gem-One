import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/gemma_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import 'scholar_screen.dart';

// ── Data models ──────────────────────────────────────────────────────────────

class _McqQuestion {
  final String question;
  final List<String> options;
  final int correctIdx;
  const _McqQuestion({required this.question, required this.options, required this.correctIdx});
}

class _FillBlank {
  final String sentence;   // contains ____ placeholder
  final String answer;
  const _FillBlank({required this.sentence, required this.answer});
}

enum _ActivityMode { quiz, fillBlanks }

// ── Screen shell ─────────────────────────────────────────────────────────────

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
                color: GemColors.studyColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GemColors.studyColor.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.menu_book_rounded, size: 15, color: GemColors.studyColor),
            ),
            const SizedBox(width: 10),
            const Text('Learn',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Upload'), Tab(text: 'Practice')],
          ),
        ),
        body: _LearnTabBody(tabs: _tabs),
      ),
    );
  }
}

// ── Shared state ─────────────────────────────────────────────────────────────

class _LearnTabBody extends StatefulWidget {
  final TabController tabs;
  const _LearnTabBody({required this.tabs});

  @override
  State<_LearnTabBody> createState() => _LearnTabBodyState();
}

class _LearnTabBodyState extends State<_LearnTabBody> {
  static const _kDoc     = 'learn_doc_text';
  static const _kName    = 'learn_doc_name';
  static const _kSummary = 'learn_summary';
  static const _kQuiz    = 'learn_quiz_json';

  String? _docText;
  String? _docName;
  String? _summary;
  List<_McqQuestion> _questions = [];
  List<_FillBlank>   _blanks    = [];
  _ActivityMode?     _activity;

  bool _analysing        = false;
  bool _generatingQuiz   = false;
  bool _generatingBlanks = false;
  bool _importingScholar = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final p    = await SharedPreferences.getInstance();
    final doc  = p.getString(_kDoc);
    final name = p.getString(_kName);
    final sum  = p.getString(_kSummary);
    final quiz = p.getString(_kQuiz);
    if (doc != null && doc.isNotEmpty) {
      setState(() {
        _docText   = doc;
        _docName   = name;
        _summary   = sum;
        _questions = quiz != null ? _parseMcq(quiz) : [];
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    final text = await File(path).readAsString();
    setState(() {
      _docText   = text;
      _docName   = result.files.first.name;
      _summary   = null;
      _questions = [];
      _blanks    = [];
      _activity  = null;
    });
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDoc, text);
    await p.setString(_kName, result.files.first.name);
    await p.remove(_kSummary);
    await p.remove(_kQuiz);
  }

  // 2000-char cap: longer inputs exceed the model's practical context window.
  String get _chunk => _docText!.length > 2000
      ? '${_docText!.substring(0, 2000)}\n[...truncated]'
      : _docText!;

  Future<void> _analyse() async {
    if (_docText == null || !mounted) return;
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) return;
    setState(() { _analysing = true; _summary = null; _questions = []; _blanks = []; _activity = null; });

    try {
      final sumReply = await service.quickReply(
        'ROLE: You are a study assistant AI.\n'
        'TASK: Read this document and write a clear summary in 5 bullet points. '
        'Then list the 5 most important concepts or facts. Use markdown.\n\nDocument:\n$_chunk',
      );
      if (!mounted) return;
      setState(() => _summary = sumReply);
      final p = await SharedPreferences.getInstance();
      await p.setString(_kSummary, sumReply);
    } catch (e) {
      if (mounted) setState(() => _summary = 'Analysis failed: $e');
    } finally {
      if (mounted) setState(() => _analysing = false);
    }
  }

  Future<void> _generateQuiz() async {
    if (_docText == null || !mounted) return;
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) return;
    setState(() { _generatingQuiz = true; _activity = _ActivityMode.quiz; });

    try {
      final reply = await service.quickReply(
        'ROLE: You are a study assistant AI.\n'
        'TASK: Generate EXACTLY 5 multiple-choice questions that test understanding of this document.\n'
        'For each question use EXACTLY this format:\n'
        'Q: [question]\n'
        'A: [option A - make this the CORRECT answer]\n'
        'B: [plausible wrong option]\n'
        'C: [plausible wrong option]\n'
        'D: [plausible wrong option]\n'
        '---\n'
        'Document:\n$_chunk',
      );
      if (!mounted) return;
      final qs = _parseMcq(reply);
      if (!mounted) return;
      if (qs.isEmpty) {
        _showSnack('Could not generate quiz. Try again.');
        setState(() => _activity = null);
        return;
      }
      setState(() => _questions = qs);
      final p = await SharedPreferences.getInstance();
      await p.setString(_kQuiz, reply);
      widget.tabs.animateTo(1);
    } catch (e) {
      if (mounted) {
        _showSnack('Quiz generation failed. Try again.');
        setState(() => _activity = null);
      }
    } finally {
      if (mounted) setState(() => _generatingQuiz = false);
    }
  }

  Future<void> _generateFillBlanks() async {
    if (_docText == null || !mounted) return;
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) return;
    setState(() { _generatingBlanks = true; _activity = _ActivityMode.fillBlanks; });

    try {
      final reply = await service.quickReply(
        'ROLE: You are a study assistant AI.\n'
        'TASK: Create exactly 5 fill-in-the-blank exercises from this document.\n'
        'Replace ONE key term in each sentence with ____.\n'
        'Use EXACTLY this format for each:\n'
        'SENTENCE: The ____ is responsible for [context].\n'
        'ANSWER: [the missing term]\n'
        '---\n'
        'Document:\n$_chunk',
      );
      if (!mounted) return;
      final blanks = _parseFillBlanks(reply);
      if (!mounted) return;
      if (blanks.isEmpty) {
        _showSnack('Could not generate exercises. Try again.');
        setState(() => _activity = null);
        return;
      }
      setState(() => _blanks = blanks);
      widget.tabs.animateTo(1);
    } catch (e) {
      if (mounted) {
        _showSnack('Exercise generation failed. Try again.');
        setState(() => _activity = null);
      }
    } finally {
      if (mounted) setState(() => _generatingBlanks = false);
    }
  }

  Future<void> _importToScholar() async {
    if (_docText == null || !mounted) return;
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) return;
    setState(() => _importingScholar = true);

    try {
      final name = _docName ?? 'Uploaded Document';
      final topicHint = _summary != null
          ? '\nTopic summary: ${_summary!.replaceAll('\n', ' ').substring(0, _summary!.length.clamp(0, 200))}'
          : '';
      final reply = await service.quickReply(
        'You are a course planner. Generate a structured course for: "$name"$topicHint\n'
        'Output ONLY this XML, no other text:\n'
        '<gem_course>\n'
        '<title>Course Title</title>\n'
        '<module id="1"><title>Module Title</title>\n'
        '  <lesson id="1.1"><title>Lesson</title><desc>Short desc</desc></lesson>\n'
        '  <lesson id="1.2"><title>Lesson</title><desc>Short desc</desc></lesson>\n'
        '  <lesson id="1.3"><title>Lesson</title><desc>Short desc</desc></lesson>\n'
        '</module>\n'
        '</gem_course>\n'
        'RULES: EXACTLY 3 modules, EXACTLY 3 lessons each. Titles under 6 words. Descriptions under 10 words.',
      );
      if (!mounted) return;
      final course = parseScholarCourseXml(reply, name);
      if (course == null) {
        _showSnack('Could not build course. Try again.');
        return;
      }
      await saveScholarCourse(course);
      if (!mounted) return;
      _showSnack('Course added to Scholar!');
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ScholarScreen()));
    } catch (e) {
      if (mounted) _showSnack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _importingScholar = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _clearDoc() async {
    setState(() { _docText = null; _docName = null; _summary = null; _questions = []; _blanks = []; _activity = null; });
    final p = await SharedPreferences.getInstance();
    await p.remove(_kDoc);
    await p.remove(_kName);
    await p.remove(_kSummary);
    await p.remove(_kQuiz);
  }

  List<_McqQuestion> _parseMcq(String raw) {
    final blocks  = raw.split(RegExp(r'---+'));
    final results = <_McqQuestion>[];
    for (final block in blocks) {
      String q = '';
      final opts = <String>[];
      for (final line in block.split('\n').map((l) => l.trim())) {
        if (line.startsWith('Q:'))       { q = line.substring(2).trim(); }
        else if (line.startsWith('A:')) { opts.add(line.substring(2).trim()); }
        else if (line.startsWith('B:')) { opts.add(line.substring(2).trim()); }
        else if (line.startsWith('C:')) { opts.add(line.substring(2).trim()); }
        else if (line.startsWith('D:')) { opts.add(line.substring(2).trim()); }
      }
      if (q.isNotEmpty && opts.length >= 2) {
        while (opts.length < 4) { opts.add('-'); }
        final correct  = opts[0];
        final shuffled = List<String>.from(opts.take(4))..shuffle();
        final idx      = shuffled.indexOf(correct).clamp(0, 3);
        results.add(_McqQuestion(question: q, options: shuffled, correctIdx: idx));
      }
    }
    return results;
  }

  List<_FillBlank> _parseFillBlanks(String raw) {
    final blocks  = raw.split(RegExp(r'---+'));
    final results = <_FillBlank>[];
    for (final block in blocks) {
      String? sentence;
      String? answer;
      for (final line in block.split('\n').map((l) => l.trim())) {
        if (line.startsWith('SENTENCE:')) sentence = line.substring(9).trim();
        if (line.startsWith('ANSWER:'))   answer   = line.substring(7).trim();
      }
      if (sentence != null && answer != null && sentence.contains('____')) {
        results.add(_FillBlank(sentence: sentence, answer: answer));
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: widget.tabs,
      children: [
        _UploadTab(
          docName:          _docName,
          docText:          _docText,
          summary:          _summary,
          analysing:        _analysing,
          generatingQuiz:   _generatingQuiz,
          generatingBlanks: _generatingBlanks,
          importingScholar: _importingScholar,
          onPickFile:       _pickFile,
          onAnalyse:        _analyse,
          onGenerateQuiz:   _generateQuiz,
          onFillBlanks:     _generateFillBlanks,
          onImportScholar:  _importToScholar,
          onClear:          _clearDoc,
        ),
        _PracticeTab(
          questions:  _questions,
          blanks:     _blanks,
          activity:   _activity,
          hasDoc:     _docText != null,
          analysed:   _summary != null,
          onGoUpload: () => widget.tabs.animateTo(0),
        ),
      ],
    );
  }
}

// ── Upload tab ───────────────────────────────────────────────────────────────

class _UploadTab extends StatelessWidget {
  final String?        docName;
  final String?        docText;
  final String?        summary;
  final bool           analysing;
  final bool           generatingQuiz;
  final bool           generatingBlanks;
  final bool           importingScholar;
  final VoidCallback   onPickFile;
  final VoidCallback   onAnalyse;
  final VoidCallback   onGenerateQuiz;
  final VoidCallback   onFillBlanks;
  final VoidCallback   onImportScholar;
  final VoidCallback   onClear;

  const _UploadTab({
    required this.docName,
    required this.docText,
    required this.summary,
    required this.analysing,
    required this.generatingQuiz,
    required this.generatingBlanks,
    required this.importingScholar,
    required this.onPickFile,
    required this.onAnalyse,
    required this.onGenerateQuiz,
    required this.onFillBlanks,
    required this.onImportScholar,
    required this.onClear,
  });

  bool get _busy => analysing || generatingQuiz || generatingBlanks || importingScholar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drop zone
          GestureDetector(
            onTap: _busy ? null : onPickFile,
            child: GlassCard(
              child: Column(children: [
                Icon(
                  docName != null ? Icons.description_outlined : Icons.upload_file_rounded,
                  size: 40,
                  color: docName != null ? GemColors.studyColor : GemColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  docName ?? 'Tap to upload a .txt file',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: docName != null ? FontWeight.w600 : FontWeight.normal,
                    color: docName != null ? GemColors.studyColor : GemColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (docText != null) ...[
                  const SizedBox(height: 6),
                  Text('${docText!.split(RegExp(r'\s+')).length} words',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
                ],
                const SizedBox(height: 4),
                Text('Supports .txt files',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
              ]),
            ),
          ),

          // Analyse button
          if (docText != null && summary == null && !_busy) ...[
            const SizedBox(height: 14),
            _ActionBtn(
              label: 'Analyse Document',
              icon: Icons.psychology_outlined,
              color: GemColors.studyColor,
              onTap: onAnalyse,
            ),
          ],

          // Loading
          if (_busy) ...[
            const SizedBox(height: 24),
            Center(child: Column(children: [
              const CircularProgressIndicator(color: GemColors.studyColor, strokeWidth: 2),
              const SizedBox(height: 12),
              Text(
                analysing        ? 'Analysing document…'
                : generatingQuiz   ? 'Generating quiz…'
                : generatingBlanks ? 'Creating fill-in-the-blanks…'
                : 'Importing to Scholar…',
                style: const TextStyle(fontSize: 13, color: GemColors.textSecondary),
              ),
            ])),
          ],

          // Summary + activity picker
          if (summary != null && !_busy) ...[
            const SizedBox(height: 16),
            _SummaryHeader(onReanalyse: onAnalyse),
            const SizedBox(height: 6),
            GlassCard(
              child: MarkdownBody(
                data: summary!,
                styleSheet: MarkdownStyleSheet(
                  p:          const TextStyle(fontSize: 14, height: 1.6, color: Colors.white),
                  h1:         const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GemColors.studyColor),
                  h2:         const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  listBullet: const TextStyle(fontSize: 14, color: Colors.white),
                  strong:     const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text('What would you like to do?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.45))),
            const SizedBox(height: 8),

            // Activity picker row
            Row(children: [
              Expanded(child: _ActivityChip(
                icon:  Icons.quiz_rounded,
                label: 'Take a Quiz',
                color: GemColors.studyColor,
                onTap: onGenerateQuiz,
              )),
              const SizedBox(width: 8),
              Expanded(child: _ActivityChip(
                icon:  Icons.edit_note_rounded,
                label: 'Fill the Blanks',
                color: const Color(0xFF74B9FF),
                onTap: onFillBlanks,
              )),
            ]),
            const SizedBox(height: 8),

            // Import to Scholar - full width
            _ActionBtn(
              label: 'Import to Scholar',
              icon:  Icons.school_rounded,
              color: GemColors.scholarColor,
              onTap: onImportScholar,
              subtitle: 'AI builds a full course from this document',
            ),

            const SizedBox(height: 12),
            _ActionBtn(
              label: 'New Document',
              icon:  Icons.delete_outline_rounded,
              color: GemColors.danger,
              onTap: onClear,
              subtle: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final VoidCallback onReanalyse;
  const _SummaryHeader({required this.onReanalyse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: GemColors.studyColor.withValues(alpha: 0.08),
      ),
      child: Row(children: [
        const SizedBox(width: 8),
        const Icon(Icons.summarize_rounded, size: 14, color: GemColors.studyColor),
        const SizedBox(width: 6),
        const Text('Summary',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: GemColors.studyColor, letterSpacing: 0.5)),
        const Spacer(),
        TextButton(
          onPressed: onReanalyse,
          style: TextButton.styleFrom(
              foregroundColor: GemColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          child: const Text('Re-analyse', style: TextStyle(fontSize: 11)),
        ),
      ]),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _ActivityChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final String?      subtitle;
  final bool         subtle;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: subtle ? color.withValues(alpha: 0.05) : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: subtle ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.6))),
            ],
          ])),
        ]),
      ),
    );
  }
}

// ── Practice tab ─────────────────────────────────────────────────────────────

class _PracticeTab extends StatefulWidget {
  final List<_McqQuestion> questions;
  final List<_FillBlank>   blanks;
  final _ActivityMode?     activity;
  final bool               hasDoc;
  final bool               analysed;
  final VoidCallback        onGoUpload;

  const _PracticeTab({
    required this.questions,
    required this.blanks,
    required this.activity,
    required this.hasDoc,
    required this.analysed,
    required this.onGoUpload,
  });

  @override
  State<_PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<_PracticeTab> {
  // Quiz state
  int  _qIdx   = 0;
  int  _qScore = 0;
  int? _tapped;
  bool _qDone  = false;

  // Fill-blanks state
  int                        _bIdx       = 0;
  final Map<int, String>     _bAnswers   = {};
  final Map<int, bool>       _bChecked   = {};
  final _bCtrl = TextEditingController();

  @override
  void didUpdateWidget(covariant _PracticeTab old) {
    super.didUpdateWidget(old);
    if (old.questions != widget.questions) _resetQuiz();
    if (old.blanks    != widget.blanks)    _resetBlanks();
  }

  @override
  void dispose() {
    _bCtrl.dispose();
    super.dispose();
  }

  void _resetQuiz()   => setState(() { _qIdx = 0; _qScore = 0; _tapped = null; _qDone = false; });
  void _resetBlanks() => setState(() { _bIdx = 0; _bAnswers.clear(); _bChecked.clear(); _bCtrl.clear(); });

  @override
  Widget build(BuildContext context) {
    if (!widget.hasDoc) {
      return _emptyState(Icons.upload_file_rounded, 'Upload a document first to practice', widget.onGoUpload);
    }
    if (!widget.analysed) {
      return _emptyState(Icons.psychology_outlined, 'Analyse your document, then choose an activity', widget.onGoUpload);
    }
    if (widget.activity == null) {
      return _emptyState(Icons.touch_app_rounded, 'Choose an activity from the Upload tab', widget.onGoUpload);
    }

    if (widget.activity == _ActivityMode.fillBlanks) {
      if (widget.blanks.isEmpty) {
        return _emptyState(Icons.edit_note_rounded, 'No exercises generated. Try again.', widget.onGoUpload);
      }
      return _buildFillBlanks();
    }

    // Quiz mode
    if (widget.questions.isEmpty) {
      return _emptyState(Icons.quiz_outlined, 'No questions generated. Try again.', widget.onGoUpload);
    }
    if (_qDone) return _buildQuizDone();
    return _buildQuiz();
  }

  // ── Quiz ──

  void _select(int i) {
    if (_tapped != null) return;
    if (i == widget.questions[_qIdx].correctIdx) _qScore++;
    setState(() => _tapped = i);
  }

  void _nextQ() {
    if (_qIdx + 1 >= widget.questions.length) {
      setState(() => _qDone = true);
    } else {
      setState(() { _qIdx++; _tapped = null; });
    }
  }

  Widget _buildQuiz() {
    final q        = widget.questions[_qIdx];
    final answered = _tapped != null;
    const letters  = ['A', 'B', 'C', 'D'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('Question ${_qIdx + 1} of ${widget.questions.length}',
              style: const TextStyle(fontSize: 13, color: GemColors.textSecondary)),
          const Spacer(),
          Text('Score: $_qScore',
              style: const TextStyle(fontSize: 13, color: GemColors.studyColor, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _qIdx / widget.questions.length,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(GemColors.studyColor),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GemColors.studyColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GemColors.studyColor.withValues(alpha: 0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.quiz_rounded, size: 20, color: GemColors.studyColor.withValues(alpha: 0.8)),
            const SizedBox(width: 12),
            Expanded(child: Text(q.question,
                style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++) ...[
          _buildOption(q, i, letters[i], answered),
          const SizedBox(height: 10),
        ],
        if (answered) ...[
          const SizedBox(height: 4),
          _buildFeedback(q),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GemColors.studyColor.withValues(alpha: 0.2),
                foregroundColor: GemColors.studyColor,
                side: BorderSide(color: GemColors.studyColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _nextQ,
              child: Text(
                _qIdx + 1 >= widget.questions.length ? 'See Results' : 'Next Question →',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildOption(_McqQuestion q, int i, String letter, bool answered) {
    final isSelected = _tapped == i;
    final isCorrect  = i == q.correctIdx;

    final Color border;
    final Color bg;
    final Color text;
    if (!answered) {
      border = GemColors.studyColor.withValues(alpha: 0.3);
      bg     = GemColors.studyColor.withValues(alpha: 0.05);
      text   = Colors.white;
    } else if (isCorrect) {
      border = GemColors.success;
      bg     = GemColors.success.withValues(alpha: 0.1);
      text   = GemColors.success;
    } else if (isSelected) {
      border = GemColors.danger;
      bg     = GemColors.danger.withValues(alpha: 0.1);
      text   = GemColors.danger;
    } else {
      border = Colors.white.withValues(alpha: 0.08);
      bg     = Colors.white.withValues(alpha: 0.02);
      text   = Colors.white.withValues(alpha: 0.35);
    }

    return GestureDetector(
      onTap: answered ? null : () => _select(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: answered && (isCorrect || isSelected) ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: answered && (isCorrect || isSelected)
                  ? (isCorrect ? GemColors.success : GemColors.danger).withValues(alpha: 0.2)
                  : GemColors.studyColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(child: answered && isCorrect
                ? const Icon(Icons.check_rounded, size: 15, color: GemColors.success)
                : answered && isSelected
                    ? const Icon(Icons.close_rounded, size: 15, color: GemColors.danger)
                    : Text(letter, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: GemColors.studyColor.withValues(alpha: 0.9)))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(q.options[i],
              style: TextStyle(fontSize: 14,
                  fontWeight: answered && isCorrect ? FontWeight.w600 : FontWeight.normal,
                  color: text))),
        ]),
      ),
    );
  }

  Widget _buildFeedback(_McqQuestion q) {
    final correct = _tapped == q.correctIdx;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (correct ? GemColors.success : GemColors.danger).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (correct ? GemColors.success : GemColors.danger).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(correct ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 17, color: correct ? GemColors.success : GemColors.danger),
        const SizedBox(width: 10),
        Expanded(child: Text(
          correct ? 'Correct!' : 'Not quite - the answer is "${q.options[q.correctIdx]}".',
          style: TextStyle(fontSize: 13, color: correct ? GemColors.success : GemColors.danger, height: 1.4),
        )),
      ]),
    );
  }

  Widget _buildQuizDone() {
    final total = widget.questions.length;
    final pct   = (_qScore / total * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _qScore == total ? Icons.workspace_premium_rounded : Icons.star_rounded,
            size: 60,
            color: _qScore >= (total * 0.8) ? GemColors.studyColor : GemColors.warning,
          ),
          const SizedBox(height: 20),
          const Text('Quiz Complete!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              color: GemColors.studyColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GemColors.studyColor.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Text('$_qScore / $total',
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: GemColors.studyColor)),
              const SizedBox(height: 4),
              Text('$pct% correct',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
            ]),
          ),
          const SizedBox(height: 16),
          Text(
            _qScore == total ? 'Perfect! Excellent understanding.'
                : _qScore >= (total * 0.6).ceil() ? 'Good work! Keep studying.'
                : 'Review the document and try again.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GemColors.studyColor.withValues(alpha: 0.2),
                foregroundColor: GemColors.studyColor,
                side: BorderSide(color: GemColors.studyColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _resetQuiz,
              child: const Text('Retry Quiz', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Fill blanks ──

  void _checkBlank() {
    final input  = _bCtrl.text.trim().toLowerCase();
    final answer = widget.blanks[_bIdx].answer.toLowerCase();
    setState(() {
      _bAnswers[_bIdx] = _bCtrl.text.trim();
      _bChecked[_bIdx] = input == answer || answer.contains(input) || input.contains(answer);
    });
  }

  void _nextBlank() {
    _bCtrl.clear();
    if (_bIdx + 1 < widget.blanks.length) {
      setState(() => _bIdx++);
    }
  }

  Widget _buildFillBlanks() {
    final blank    = widget.blanks[_bIdx];
    final checked  = _bChecked[_bIdx];
    final isCorrect = checked == true;
    final total     = widget.blanks.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('${_bIdx + 1} of $total',
              style: const TextStyle(fontSize: 13, color: GemColors.textSecondary)),
          const Spacer(),
          Text('Fill in the Blank',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _bIdx / total,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF74B9FF)),
          ),
        ),
        const SizedBox(height: 20),

        // Sentence with blank highlighted
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF74B9FF).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF74B9FF).withValues(alpha: 0.2)),
          ),
          child: Text(blank.sentence,
              style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.6)),
        ),
        const SizedBox(height: 20),

        // Input
        if (checked == null) ...[
          TextField(
            controller: _bCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              hintText: 'Type your answer…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF74B9FF).withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF74B9FF).withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF74B9FF)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _checkBlank(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _checkBlank,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF74B9FF).withValues(alpha: 0.2),
                foregroundColor: const Color(0xFF74B9FF),
                side: const BorderSide(color: Color(0xFF74B9FF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Check', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],

        // Feedback
        if (checked != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isCorrect ? GemColors.success : GemColors.danger).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (isCorrect ? GemColors.success : GemColors.danger).withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(isCorrect ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    size: 17, color: isCorrect ? GemColors.success : GemColors.danger),
                const SizedBox(width: 8),
                Text(isCorrect ? 'Correct!' : 'Not quite',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: isCorrect ? GemColors.success : GemColors.danger)),
              ]),
              if (!isCorrect) ...[
                const SizedBox(height: 6),
                Text('Answer: ${blank.answer}',
                    style: TextStyle(fontSize: 13, color: GemColors.danger.withValues(alpha: 0.8))),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _bIdx + 1 < total ? _nextBlank : _resetBlanks,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF74B9FF).withValues(alpha: 0.2),
                foregroundColor: const Color(0xFF74B9FF),
                side: const BorderSide(color: Color(0xFF74B9FF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _bIdx + 1 < total ? 'Next →' : 'Try Again',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _emptyState(IconData icon, String text, VoidCallback onTap) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: GemColors.studyColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(fontSize: 15, color: GemColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: GemColors.studyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GemColors.studyColor.withValues(alpha: 0.4)),
              ),
              child: const Text('Go to Upload',
                  style: TextStyle(color: GemColors.studyColor, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
