import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/gemma_service.dart';
import '../core/theme.dart';
import '../widgets/animated_background.dart';
import 'scholar_screen.dart';

// quiz XML format: <quiz><q>...</q><o>A</o><o>B</o><a>A</a></quiz>

final RegExp _quizRegex = RegExp(
  r'<quiz>([\s\S]*?)<\/quiz>',
  caseSensitive: false,
);

final RegExp _innerTagRegex = RegExp(
  r'<(\w+)>([\s\S]*?)<\/\1>',
  caseSensitive: false,
);

class _QuizData {
  final String question;
  final List<String> options;
  final int correctIndex; // 0-based

  const _QuizData({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  static _QuizData? tryParse(String text) {
    final m = _quizRegex.firstMatch(text);
    if (m == null) return null;
    final body = m.group(1) ?? '';

    String? question;
    final options = <String>[];
    String? answerLetter;

    for (final tag in _innerTagRegex.allMatches(body)) {
      final name = tag.group(1)?.toLowerCase();
      final val  = tag.group(2)?.trim() ?? '';
      if (name == 'q')      { question = val; }
      else if (name == 'o') { options.add(val); }
      else if (name == 'a') { answerLetter = val.toUpperCase(); }
    }

    if (question == null || options.length < 2 || answerLetter == null) {
      return null;
    }
    final idx = answerLetter.codeUnitAt(0) - 'A'.codeUnitAt(0);
    if (idx < 0 || idx >= options.length) return null;

    return _QuizData(question: question, options: options, correctIndex: idx);
  }
}

enum _MsgKind { user, bot, loading }

class _Msg {
  final _MsgKind kind;
  final String   text;
  final _QuizData? quiz;

  const _Msg._({required this.kind, required this.text, this.quiz});

  factory _Msg.user(String t) => _Msg._(kind: _MsgKind.user, text: t);

  factory _Msg.bot(String raw) {
    final quiz = _QuizData.tryParse(raw);
    final display = quiz != null
        ? raw.replaceAll(_quizRegex, '').trim()
        : raw;
    return _Msg._(kind: _MsgKind.bot, text: display, quiz: quiz);
  }

  static const loading = _Msg._(kind: _MsgKind.loading, text: '');

  bool get isUser    => kind == _MsgKind.user;
  bool get isLoading => kind == _MsgKind.loading;
}

class ScholarLessonScreen extends StatefulWidget {
  final ScholarCourse course;
  final ScholarLesson lesson;
  final Future<void> Function() onComplete;

  const ScholarLessonScreen({
    super.key,
    required this.course,
    required this.lesson,
    required this.onComplete,
  });

  @override
  State<ScholarLessonScreen> createState() => _ScholarLessonScreenState();
}

class _ScholarLessonScreenState extends State<ScholarLessonScreen> {
  final List<_Msg> _msgs     = [];
  final _inputCtrl           = TextEditingController();
  final _scrollCtrl          = ScrollController();

  InferenceChat? _chat;
  bool _loading  = false;
  bool _done     = false;
  int  _exchanges = 0;

  String get _prompt => '''
IDENTITY: You are Scholar, a personal AI tutor inside Gem One. Never say you are "Gemma", "Google", or "DeepMind".

CURRENT LESSON:
- Course: ${widget.course.title}
- Module: ${widget.lesson.moduleTitle}
- Lesson: ${widget.lesson.title}
${widget.lesson.desc.isNotEmpty ? '- Description: ${widget.lesson.desc}' : ''}

YOUR JOB: Teach this exact lesson topic clearly and concisely.

WORKFLOW:
1. Explain the topic in 2-3 SHORT paragraphs (3-4 sentences each). Use markdown: **bold** for key terms, `code` for code/syntax, bullet lists for steps. No walls of text.
2. After your explanation, emit ONE quiz block to test understanding:
<quiz>
<q>Your question here?</q>
<o>Option A</o>
<o>Option B</o>
<o>Option C</o>
<o>Option D</o>
<a>B</a>
</quiz>
The <a> tag must be the letter A, B, C, or D of the correct option.
3. If the student answered wrong: explain that specific concept more clearly, then emit a new quiz.
4. If the student answered correctly: congratulate them and offer to explain more or answer questions.
5. Always answer follow-up questions about this lesson topic.

RULES:
- Stay on this lesson topic only.
- Plain, friendly language. Explain jargon when you use it.
- Never reveal the answer before the student attempts the quiz.
- The <a> letter MUST match the correct <o> option.
''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) {
      _appendBot('The AI model is still loading. Please wait a moment and try again.');
      return;
    }
    _chat = await service.switchMission(
      Mission.scholar,
      customPrompt: _prompt,
    );
    if (!mounted) return;
    await _rawSend('Begin the lesson now.');
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _appendBot(String text) {
    if (!mounted) return;
    setState(() => _msgs.add(_Msg.bot(text)));
    _scrollDown();
  }

  // Sends a prompt without showing a user bubble - used for lesson start and quiz feedback.
  Future<void> _rawSend(String prompt) async {
    if (_loading || _chat == null) return;
    setState(() { _msgs.add(_Msg.loading); _loading = true; });
    _scrollDown();

    _exchanges++;
    // reset the chat session before the context fills; prevents single-word collapse at token limit
    if (_exchanges > 5) {
      final service = GemmaServiceProvider.of(context);
      _chat = await service.switchMission(Mission.scholar, customPrompt: _prompt);
      if (!mounted) return;
      _exchanges = 0;
    }

    try {
      await _chat!.addQueryChunk(Message.text(text: prompt, isUser: true));
      final buf = StringBuffer();
      await for (final ev in _chat!.generateChatResponseAsync()) {
        if (!mounted) break;
        if (ev is TextResponse) buf.write(ev.token);
      }
      if (!mounted) return;
      final response = buf.toString().trim();
      setState(() {
        _msgs.removeLast();
        _msgs.add(_Msg.bot(response));
      });
      _scrollDown();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _msgs.removeLast();
        _msgs.add(_Msg.bot('Something went wrong. Please try again.'));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _userSend() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    _inputCtrl.clear();
    setState(() => _msgs.add(_Msg.user(text)));
    _scrollDown();
    await _rawSend(text);
  }

  Future<void> _onAnswer(_QuizData quiz, int selected) async {
    final correct = selected == quiz.correctIndex;
    if (correct) {
      if (!_done) {
        _done = true;
        setState(() {});
        await widget.onComplete();
      }
      // Don't send to AI after correct - context is near-full after a quiz
      // exchange and the model collapses to one-word replies. Show local message.
      if (mounted) {
        setState(() => _msgs.add(_Msg.bot(
          'Correct! Lesson complete. Head back to your course to continue, '
          'or ask me any follow-up questions about this topic.',
        )));
        _scrollDown();
      }
    } else {
      await _rawSend(
        'I answered "${quiz.options[selected]}" for "${quiz.question}" but was wrong. '
        'In 2-3 sentences explain why, then give me one new quiz on the same concept.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GemColors.bg,
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Column(children: [
            _buildHeader(),
            Expanded(child: _buildList()),
            _buildInput(),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(
            color: GemColors.scholarColor.withValues(alpha: 0.15))),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: Colors.white,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: GemColors.scholarColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: GemColors.scholarColor.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.school_rounded,
              size: 16, color: GemColors.scholarColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.lesson.title,
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.lesson.moduleTitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (_done)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: GemColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: GemColors.success.withValues(alpha: 0.4)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_rounded, size: 12, color: GemColors.success),
              SizedBox(width: 4),
              Text('Completed',
                  style: TextStyle(
                    fontSize: 11, color: GemColors.success,
                    fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }

  Widget _buildList() {
    if (_msgs.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: GemColors.scholarColor.withValues(alpha: 0.6),
          strokeWidth: 2),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _msgs.length,
      itemBuilder: (_, i) => _buildItem(_msgs[i], i),
    );
  }

  Widget _buildItem(_Msg msg, int idx) {
    if (msg.isLoading) return const _TypingIndicator();

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: GemColors.scholarColor.withValues(alpha: 0.16),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(
              color: GemColors.scholarColor.withValues(alpha: 0.28)),
          ),
          child: Text(msg.text,
              style: const TextStyle(
                fontSize: 14, color: Colors.white, height: 1.5)),
        ),
      );
    }

    // Bot
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (msg.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8, right: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF14142E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: const Color(0xFF1E1E3F)),
            ),
            child: MarkdownBody(
              data: msg.text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                    fontSize: 14, color: Colors.white, height: 1.6),
                strong: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
                em: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic),
                code: TextStyle(
                    fontSize: 13,
                    color: GemColors.scholarColor,
                    fontFamily: 'monospace',
                    backgroundColor:
                        GemColors.scholarColor.withValues(alpha: 0.1)),
                codeblockDecoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                      left: BorderSide(
                          color: GemColors.scholarColor.withValues(alpha: 0.5),
                          width: 3)),
                ),
                listBullet: const TextStyle(
                    fontSize: 14, color: Colors.white),
              ),
            ),
          ),
        if (msg.quiz != null)
          _QuizWidget(
            quiz: msg.quiz!,
            onAnswer: (sel) => _onAnswer(msg.quiz!, sel),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildInput() {
    if (_done) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to Course'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.success.withValues(alpha: 0.12),
              foregroundColor: GemColors.success,
              side: BorderSide(color: GemColors.success.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        border: Border(
          top: BorderSide(
            color: GemColors.scholarColor.withValues(alpha: 0.12))),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _inputCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            onSubmitted: (_) => _userSend(),
            decoration: InputDecoration(
              hintText: 'Ask anything about this lesson...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.28), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
              filled: true,
              fillColor: const Color(0xFF0D0B1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: GemColors.scholarColor.withValues(alpha: 0.18)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: GemColors.scholarColor.withValues(alpha: 0.18)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: GemColors.scholarColor.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _loading ? null : _userSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _loading
                  ? GemColors.scholarColor.withValues(alpha: 0.12)
                  : GemColors.scholarColor.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _loading
                  ? Icons.hourglass_empty_rounded
                  : Icons.send_rounded,
              size: 18,
              color: _loading
                  ? GemColors.scholarColor.withValues(alpha: 0.4)
                  : Colors.white,
            ),
          ),
        ),
      ]),
    );
  }
}

class _QuizWidget extends StatefulWidget {
  final _QuizData quiz;
  final void Function(int selectedIndex) onAnswer;

  const _QuizWidget({required this.quiz, required this.onAnswer});

  @override
  State<_QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<_QuizWidget> {
  int? _selected;
  bool _answered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0B1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GemColors.scholarColor.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: GemColors.scholarColor.withValues(alpha: 0.06),
            blurRadius: 18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.quiz_rounded,
                size: 13,
                color: GemColors.scholarColor.withValues(alpha: 0.75)),
            const SizedBox(width: 5),
            Text(
              'QUIZ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: GemColors.scholarColor.withValues(alpha: 0.75),
                letterSpacing: 1.0),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            widget.quiz.question,
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 12),
          ...widget.quiz.options.asMap().entries.map((e) {
            final i      = e.key;
            final opt    = e.value;
            final letter = String.fromCharCode('A'.codeUnitAt(0) + i);
            final isSel  = _selected == i;
            final isCorr = i == widget.quiz.correctIndex;

            Color bg, borderColor, textClr;
            if (!_answered) {
              bg          = isSel
                  ? GemColors.scholarColor.withValues(alpha: 0.14)
                  : Colors.transparent;
              borderColor = isSel
                  ? GemColors.scholarColor.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.09);
              textClr     = Colors.white;
            } else if (isCorr) {
              bg          = GemColors.success.withValues(alpha: 0.11);
              borderColor = GemColors.success.withValues(alpha: 0.45);
              textClr     = GemColors.success;
            } else if (isSel) {
              bg          = GemColors.danger.withValues(alpha: 0.11);
              borderColor = GemColors.danger.withValues(alpha: 0.45);
              textClr     = GemColors.danger;
            } else {
              bg          = Colors.transparent;
              borderColor = Colors.white.withValues(alpha: 0.05);
              textClr     = Colors.white.withValues(alpha: 0.35);
            }

            return GestureDetector(
              onTap: _answered
                  ? null
                  : () {
                      setState(() { _selected = i; _answered = true; });
                      widget.onAnswer(i);
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: _answered && isCorr
                          ? GemColors.success.withValues(alpha: 0.18)
                          : _answered && isSel
                              ? GemColors.danger.withValues(alpha: 0.18)
                              : GemColors.scholarColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: textClr),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(opt,
                        style: TextStyle(
                          fontSize: 13, color: textClr, height: 1.4)),
                  ),
                  if (_answered && isCorr)
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: GemColors.success),
                  if (_answered && isSel && !isCorr)
                    const Icon(Icons.cancel_rounded,
                        size: 16, color: GemColors.danger),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final v = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
              final opacity = 0.3 + 0.7 * (v < 0.5 ? v * 2 : (1 - v) * 2);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: GemColors.scholarColor.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
