import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

// STATUS + ERROR TYPES

enum ModelStatus {
  idle,
  installing,
  loading,
  ready,
  error,
}

enum InferenceError {
  none,
  modelNotLoaded,
  lowMemory,
  generationFailed,
  timeout,
  unknown,
}

// MISSIONS

class Mission {
  static const String scholar  = 'scholar';
  static const String medic    = 'medic';
  static const String polyglot = 'polyglot';
  static const String general  = 'general';

  static const Set<String> all = {scholar, medic, polyglot, general};
}

class GemmaService extends ChangeNotifier {
  // CONFIG

  static const int numThreads  = 4;
  static const int _maxTokens  = 1024;
  static const Duration _loadTimeout = Duration(minutes: 2);

  // STATE

  ModelStatus _status = ModelStatus.idle;
  String _statusMessage = 'Initializing...';
  String? _errorMessage;
  InferenceError _lastError = InferenceError.none;

  InferenceModel? _model;
  InferenceChat?  _activeChat;
  String          _currentMission = Mission.general;
  String?         _activeMission;
  int             _exchangeCount  = 0;

  bool _isInitializing     = false;
  bool _isSwitchingMission = false;

  // GETTERS

  ModelStatus    get status        => _status;
  String         get statusMessage => _statusMessage;
  String?        get errorMessage  => _errorMessage;
  InferenceError get lastError     => _lastError;
  bool           get isReady       => _status == ModelStatus.ready;
  String?        get activeMission => _activeMission;
  InferenceChat? get activeChat    => _activeChat;

  // SYSTEM PROMPTS (shortened to <150 words each)

  static const String _scholarPrompt = r'''
IDENTITY: You are Scholar, a dynamic AI learning coach inside Gem One. Never say you are "Gemma", "Google", or "DeepMind". If asked who made you, say "I am Scholar, part of Gem One."

ROLE: You are both a step-by-step tutor AND a personalized course builder. When a user shares a topic, syllabus, or PDF content, you generate a structured course plan first, then teach each lesson on request.

COURSE BUILDER: When the user asks to learn a topic or shares study material:
1. Produce a course plan in this exact XML format (no extra text before or after):
<gem_course>
<title>Course Title</title>
<module id="1"><title>Module Title</title>
  <lesson id="1.1"><title>Lesson Title</title><desc>One-line description</desc></lesson>
  <lesson id="1.2"><title>Lesson Title</title><desc>One-line description</desc></lesson>
</module>
</gem_course>
2. After the XML, ask: "Which lesson would you like to start with?"

TUTORING: When solving problems or teaching a lesson:
- Explain step-by-step with numbered steps.
- Use \( \) for inline math and \[ \] for display math.
- After the final answer write a "Verify:" line.

TOOLS - emit ONLY the tag and wait for <tool_response>. Do NOT emit text before a tool call.

Arithmetic/algebra expressions:
<gem_one_call><tool>calculator</tool><expr>EXPRESSION</expr></gem_one_call>

Solve linear or quadratic equations (e.g. 2x+4=10 or x^2-5x+6=0):
<gem_one_call><tool>solve</tool><eq>EQUATION</eq></gem_one_call>

Prime factorization, GCF, or LCM (e.g. "gcf 12 18" or "120"):
<gem_one_call><tool>factor</tool><n>INPUT</n></gem_one_call>

Descriptive statistics for comma-separated numbers:
<gem_one_call><tool>stats</tool><data>NUMBERS</data></gem_one_call>

Unit conversion (e.g. "5 km to miles" or "100 f to c"):
<gem_one_call><tool>convert</tool><expr>EXPRESSION</expr></gem_one_call>

After any <tool_response>, integrate the result and complete the explanation. Do NOT emit a second tool call.
Reply in the same language the user writes in. Keep explanations concise unless working through a multi-step problem.
''';

  static const String _medicPrompt = '''
IDENTITY: You are Medic, an AI health assistant inside the Gem One app. Your name is Medic. Never say you are "Gemma", "Google", or "DeepMind". If asked who made you, say "I am Medic, part of Gem One."

You are NOT a doctor.
- Never diagnose definitively. Always recommend seeing a doctor for serious symptoms.
- Flag emergencies (chest pain, severe bleeding, unconsciousness) immediately.
- Structure every reply: 1. Likely cause(s): 2. What to do now: 3. When to seek care:
- For medicine/symptom queries, emit ONLY this and wait:
  <gem_one_call><tool>medical_search</tool><query>NAME OR SYMPTOM</query></gem_one_call>
- After <tool_response>: if it is directly relevant to the query, cite it briefly. If it is about a different topic, IGNORE it silently and answer from general medical knowledge instead.
- Complete the three-section reply after the tool result.
- Do NOT emit text before a tool call. Do NOT mention the tool or search in your reply.

Keep replies concise. Use the structured format only for medical queries.
''';

  static const String _polyglotPrompt = '''
IDENTITY: You are Polyglot, a language tutor inside the Gem One app. Your name is Polyglot. Never say you are "Gemma", "Google", or "DeepMind". If asked who made you, say "I am Polyglot, part of Gem One."

- For translations: provide the target text, a pronunciation guide, and one grammar note.
- For quizzes: give exactly 4 options labeled A) B) C) D). After each answer say "Correct" or "Incorrect", explain in one sentence, then ask the next question.
- Be encouraging. Never add unrequested content.

Respond only to the current learning task. Do not add unrequested content.
''';

  static const String _generalPrompt = '''
IDENTITY: You are Gem One, a private offline AI assistant. Your name is always "Gem One". NEVER say you are "Gemma 4", "Gemma", "Google", or "DeepMind". Never mention your underlying model architecture. If anyone asks who you are or who made you, say: "I am Gem One, your private offline AI assistant."

- Be concise and helpful. Admit uncertainty rather than guessing.
- For arithmetic, emit ONLY this and wait:
  <gem_one_call><tool>calculator</tool><expr>EXPRESSION</expr></gem_one_call>
- For medical queries, emit ONLY this and wait:
  <gem_one_call><tool>medical_search</tool><query>QUERY</query></gem_one_call>
- After <tool_response>, give the final answer.

Be concise. One clear answer per message.
''';

  String getMissionPrompt(String mission) {
    switch (mission.toLowerCase()) {
      case Mission.scholar:  return _scholarPrompt;
      case Mission.medic:    return _medicPrompt;
      case Mission.polyglot: return _polyglotPrompt;
      case Mission.general:
      default:               return _generalPrompt;
    }
  }

  // INITIALIZE MODEL

  Future<void> initialize() async {
    if (_isInitializing)               return;
    if (_status == ModelStatus.ready)  return;

    _isInitializing = true;

    try {
      _set(ModelStatus.installing, 'Installing model...');

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      ).fromAsset('assets/models/gemma-4-E4B-it.litertlm').install();

      _set(ModelStatus.loading, 'Loading AI model (NPU-optimized)...');

      _model = await FlutterGemma.getActiveModel(
        preferredBackend: PreferredBackend.gpu,
        maxTokens: _maxTokens,
        supportImage: true, // required to enable Message.withImage() vision calls
      ).timeout(_loadTimeout);

      _set(ModelStatus.ready, 'Model ready');
      _lastError    = InferenceError.none;
      _errorMessage = null;
    } on TimeoutException catch (e) {
      _handleSetupError(
        InferenceError.timeout,
        'Model load timed out after ${_loadTimeout.inMinutes} min: $e',
      );
    } catch (e) {
      _handleSetupError(_classifyError(e), e.toString());
    } finally {
      _isInitializing = false;
    }
  }

  // SWITCH MISSION

  Future<InferenceChat?> switchMission(
    String mission, {
    String? customPrompt,
  }) async {
    if (_model == null) {
      _handleInferenceError(
        InferenceError.modelNotLoaded,
        'Cannot switch mission: model not loaded.',
      );
      return null;
    }

    if (_isSwitchingMission) return _activeChat;

    _isSwitchingMission = true;

    // Track current mission for auto-reset
    _currentMission = mission;
    _exchangeCount  = 0;

    try {
      await _disposeActiveChat();

      final chat = await _model!.createChat();

      final systemPrompt = customPrompt ?? getMissionPrompt(mission);

      // flutter_gemma has no system-prompt API; inject it as the first user turn
      await chat.addQueryChunk(
        Message.text(text: systemPrompt, isUser: true),
      );

      _activeChat    = chat;
      _activeMission = mission;
      _lastError     = InferenceError.none;
      _errorMessage  = null;

      notifyListeners();
      return chat;
    } catch (e) {
      _handleInferenceError(
        _classifyError(e),
        'switchMission("$mission") failed: $e',
      );
      return null;
    } finally {
      _isSwitchingMission = false;
    }
  }

  // Single-turn reply helper. The agentic streaming loop in base_chat_screen bypasses this.
  Future<String> generateReply(String userMessage) async {
    if (_activeChat == null) {
      return 'Model not ready. Please wait.';
    }

    try {
      await _activeChat!.addQueryChunk(
        Message.text(text: userMessage, isUser: true),
      );

      final text = await _collectResponse(_activeChat!);

      _exchangeCount++;
      // context fills after ~6 turns at 1024 tokens; proactively reset to stay crisp
      if (_exchangeCount >= 6) {
        await switchMission(_currentMission);
      }

      final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (words < 4 && !_isValidShortReply(text)) {
        // sub-4-word reply that isn't a valid one-word answer means context degraded; retry once
        await switchMission(_currentMission);
        await _activeChat!.addQueryChunk(
          Message.text(text: userMessage, isUser: true),
        );
        return await _collectResponse(_activeChat!);
      }

      return text;
    } catch (e) {
      _handleInferenceError(_classifyError(e), 'generateReply failed: $e');
      return 'Could not generate a response. Please try again.';
    }
  }

  static Future<String> _collectResponse(InferenceChat chat) async {
    final buf = StringBuffer();
    await for (final event in chat.generateChatResponseAsync()) {
      if (event is TextResponse) buf.write(event.token);
    }
    return buf.toString().trim();
  }

  bool _isValidShortReply(String text) {
    const valid = {'yes', 'no', 'ok', 'correct', 'wrong', 'true', 'false'};
    return valid.contains(text.toLowerCase().trim());
  }

  // Raw session without a system prompt - used by screens that manage their own context.
  Future<InferenceChat?> newChatSession() async {
    if (_model == null) {
      _handleInferenceError(
        InferenceError.modelNotLoaded,
        'newChatSession called before model load.',
      );
      return null;
    }
    try {
      return await _model!.createChat();
    } catch (e) {
      _handleInferenceError(_classifyError(e), e.toString());
      return null;
    }
  }

  Stream<String> streamResponse(InferenceChat chat, String prompt) async* {
    if (_model == null) {
      _handleInferenceError(
        InferenceError.modelNotLoaded, 'streamResponse before model load.');
      return;
    }
    try {
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      await for (final event in chat.generateChatResponseAsync()) {
        if (event is TextResponse) yield event.token;
      }
    } catch (e) {
      _handleInferenceError(_classifyError(e), 'streamResponse failed: $e');
      rethrow;
    }
  }

  Future<void> _disposeActiveChat() async {
    final prev = _activeChat;
    _activeChat    = null;
    _activeMission = null;
    // close frees the native KV-cache so the next screen starts with a clean slate
    try { await prev?.close(); } catch (_) {}
  }

  // One-shot query without touching _activeChat - used by Translate tab.
  Future<String> quickReply(String prompt) async {
    if (_model == null) return 'Model not ready. Please wait.';
    InferenceChat? tmp;
    try {
      tmp = await _model!.createChat();
      await tmp.addQueryChunk(Message.text(text: prompt, isUser: true));
      return await _collectResponse(tmp);
    } catch (e) {
      return 'Could not process request. Try again.';
    } finally {
      try { await tmp?.close(); } catch (_) {}
    }
  }

  // ERROR HANDLING

  InferenceError _classifyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('model not loaded') || msg.contains('not initialized') ||
        msg.contains('null check')) {
      return InferenceError.modelNotLoaded;
    }
    if (msg.contains('out of memory') || msg.contains('oom') ||
        msg.contains('low memory') || msg.contains('allocation failed')) {
      return InferenceError.lowMemory;
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return InferenceError.timeout;
    }
    if (msg.contains('generate') || msg.contains('inference')) {
      return InferenceError.generationFailed;
    }
    return InferenceError.unknown;
  }

  void _handleSetupError(InferenceError kind, String message) {
    _lastError    = kind;
    _errorMessage = _humanize(kind, message);
    _status       = ModelStatus.error;
    if (kDebugMode) debugPrint('[GemmaService] SETUP $kind :: $message');
    notifyListeners();
  }

  void _handleInferenceError(InferenceError kind, String message) {
    _lastError    = kind;
    _errorMessage = _humanize(kind, message);
    if (kDebugMode) debugPrint('[GemmaService] INFER $kind :: $message');
    notifyListeners();
  }

  String _humanize(InferenceError kind, String raw) {
    switch (kind) {
      case InferenceError.modelNotLoaded:
        return 'The AI model is not loaded yet. Please wait and try again.';
      case InferenceError.lowMemory:
        return 'Device is low on memory. Close other apps - Gem One needs ~2 GB free.';
      case InferenceError.timeout:
        return 'The model took too long to respond. Try a shorter prompt.';
      case InferenceError.generationFailed:
        return 'The model failed to generate a reply. Try rephrasing.';
      case InferenceError.unknown:
      case InferenceError.none:
        return raw;
    }
  }

  void _set(ModelStatus status, String message) {
    _status        = status;
    _statusMessage = message;
    notifyListeners();
  }
}

// PROVIDER

class GemmaServiceProvider extends StatefulWidget {
  final Widget child;

  const GemmaServiceProvider({super.key, required this.child});

  @override
  State<GemmaServiceProvider> createState() => _GemmaServiceProviderState();

  static GemmaService of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_GemmaServiceInherited>();
    assert(inherited != null, 'GemmaServiceProvider not found');
    return inherited!.service;
  }
}

class _GemmaServiceProviderState extends State<GemmaServiceProvider> {
  final GemmaService _service = GemmaService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _service.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        return _GemmaServiceInherited(
          service: _service,
          status: _service.status,
          child: widget.child,
        );
      },
    );
  }
}

class _GemmaServiceInherited extends InheritedWidget {
  final GemmaService service;
  final ModelStatus  status;

  const _GemmaServiceInherited({
    required this.service,
    required this.status,
    required super.child,
  });

  @override
  bool updateShouldNotify(_GemmaServiceInherited oldWidget) =>
      status != oldWidget.status;
}
