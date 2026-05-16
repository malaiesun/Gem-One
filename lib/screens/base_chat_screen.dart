import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../core/gemma_service.dart';
import '../core/theme.dart';
import '../core/xml_parser.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/suggestion_chips.dart';

abstract class BaseChatState<T extends StatefulWidget> extends State<T> {

  /// Mission type used for switchMission(). Default: Mission.general.
  String get missionType => Mission.general;

  /// Key used to persist messages. Override for screens sharing the same mission
  /// type (e.g. per-lesson chats in Polyglot).
  String get persistenceKey => missionType;

  /// Optional custom prompt override (e.g. Polyglot's dynamic language prompt).
  String? get customMissionPrompt => null;

  /// Whether to render LaTeX in assistant messages. Scholar overrides to true.
  bool get useMathRendering => false;

  String get moduleName;
  IconData get moduleIcon;
  Color get moduleColor;
  String get inputHint => 'Type a message...';
  List<String> get emptyStateHints => [];
  Widget? buildHeader() => null;

  // Called once after the chat session is ready. Override to auto-send an
  // opening message (e.g. lesson auto-start).
  void onChatReady() {}

  // Optional widget rendered above the input bar (e.g. quiz choice buttons).
  Widget? buildExtraInput() => null;

  // Legacy - no longer used by base but kept so old subclasses still compile.
  String get systemPrompt => '';

  // Static so messages survive pop/push navigation within the same app session;
  // keyed by persistenceKey to allow per-lesson isolation (e.g. Polyglot).
  static final Map<String, List<ChatMessage>> _persistedMessages = {};

  static void clearHistory() => _persistedMessages.clear();

  final List<ChatMessage> messages = [];
  InferenceChat? _chat;
  bool _loading = false;
  bool _cancelled = false;
  bool _showContextBanner = false;
  int _exchangeCount = 0;

  // Protected read-only access for subclasses
  InferenceChat? get chat => _chat;
  bool get loading => _loading;

  void stopGeneration() {
    if (_loading) setState(() => _cancelled = true);
  }

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  Future<void> _initChat({bool clearHistory = false}) async {
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) return;

    if (clearHistory) _persistedMessages.remove(missionType);

    final chat = await service.switchMission(
      missionType,
      customPrompt: customMissionPrompt,
    );

    if (!mounted) return;
    setState(() {
      _chat = chat;
      messages
        ..clear()
        ..addAll(_persistedMessages[persistenceKey] ?? []);
      _exchangeCount = 0;
    });
    onChatReady();
  }

  @override
  void dispose() {
    _persistedMessages[persistenceKey] = List.from(messages);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
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

  // Caps the agentic loop to prevent infinite tool-call cycles.
  static const int _maxToolHops = 3;

  Future<void> sendMessage(String text, {String? internalPrompt}) async {
    if (_loading || !mounted) return;
    _cancelled = false;

    final service = GemmaServiceProvider.of(context);

    // Auto-reset if exchange count is too high (prevents KV-cache overflow)
    _exchangeCount++;
    if (_exchangeCount > 6) {
      final newChat = await service.switchMission(
        missionType,
        customPrompt: customMissionPrompt,
      );
      if (!mounted) return;
      setState(() {
        _chat = newChat;
        _exchangeCount = 1;
        _showContextBanner = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showContextBanner = false);
      });
    }

    if (_chat == null || !mounted) return;

    setState(() {
      messages.add(ChatMessage(text: text, isUser: true));
      messages.add(const ChatMessage(text: '', isUser: false, isLoading: true));
      _loading = true;
    });
    _scrollToBottom();

    try {
      String nextPrompt = internalPrompt ?? text;
      bool finalAnswerReady = false;

      for (int hop = 0; hop < _maxToolHops && !finalAnswerReady; hop++) {
        if (!mounted) break;

        await _chat!.addQueryChunk(
          Message.text(text: nextPrompt, isUser: true),
        );

        String buffer = '';
        bool toolDetected = false;

        await for (final event in _chat!.generateChatResponseAsync()) {
          if (!mounted || _cancelled) break;
          if (event is! TextResponse) continue;
          buffer += event.token;

          if (!toolDetected) {
            final openIdx = buffer.indexOf(ToolParser.openTag);
            if (openIdx >= 0) {
              toolDetected = true;
              _showToolActive(preText: buffer.substring(0, openIdx), tool: 'detecting…');
              continue;
            }

            final hold = ToolParser.trailingPartialOpenLength(buffer);
            final visible = hold == 0
                ? buffer
                : buffer.substring(0, buffer.length - hold);

            if (mounted) {
              setState(() {
                messages[messages.length - 1] = ChatMessage(
                  text: visible,
                  isUser: false,
                  useMath: useMathRendering,
                  isStreaming: true,
                );
              });
              _scrollToBottom();
            }
          }
        }

        if (!mounted || _cancelled) {
          if (_cancelled && buffer.isNotEmpty && mounted) {
            setState(() {
              messages[messages.length - 1] = ChatMessage(
                text: buffer.trim(),
                isUser: false,
                isStreaming: false,
              );
            });
          }
          break;
        }

        final call = toolDetected ? ToolParser.parse(buffer) : null;

        if (call == null) {
          final cleaned = ToolParser.stripCalls(buffer);
          final wordCount = cleaned.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

          // Very short non-semantic output signals KV-cache corruption; reset the session.
          if (wordCount < 4 && !_isValidShortReply(cleaned.trim())) {
            final newChat = await service.switchMission(
              missionType,
              customPrompt: customMissionPrompt,
            );
            if (!mounted) break;
            setState(() {
              _chat = newChat;
              _exchangeCount = 0;
              messages[messages.length - 1] = const ChatMessage(
                text: 'Context refreshed - please resend your question.',
                isUser: false,
              );
            });
          } else {
            if (mounted) {
              setState(() {
                messages[messages.length - 1] = ChatMessage(
                  text: cleaned,
                  isUser: false,
                  useMath: useMathRendering,
                  isStreaming: false,
                );
              });
            }
          }
          finalAnswerReady = true;
          break;
        }

        if (!mounted) break;

        _showToolActive(
          preText: buffer.substring(0, ToolParser.firstOpen(buffer)),
          tool: ToolDispatcher.label(call.tool),
        );
        final result = await ToolDispatcher.execute(call);
        if (!mounted) break;
        nextPrompt = ToolParser.formatResponse(call.tool, result);

        setState(() {
          messages[messages.length - 1] =
              const ChatMessage(text: '', isUser: false, isLoading: true);
        });
        _scrollToBottom();
      }

      if (mounted && !finalAnswerReady) {
        setState(() {
          messages[messages.length - 1] = const ChatMessage(
            text: 'I had trouble composing a final answer. Please rephrase the question.',
            isUser: false,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (messages.isNotEmpty) messages.removeLast();
          messages.add(ChatMessage(text: 'Error: $e', isUser: false));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isValidShortReply(String text) {
    const valid = {'yes', 'no', 'ok', 'correct', 'wrong', 'true', 'false'};
    return valid.contains(text.toLowerCase());
  }

  void _showToolActive({required String preText, required String tool}) {
    final preface = preText.trim();
    setState(() {
      messages[messages.length - 1] = ChatMessage(
        text: preface,
        isUser: false,
        isToolActive: true,
        toolLabel: tool,
      );
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final service = GemmaServiceProvider.of(context);
    final ready = service.isReady && _chat != null;

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Context refresh banner
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _showContextBanner
                  ? Padding(
                      key: const ValueKey('banner'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 14, color: GemColors.accent),
                            const SizedBox(width: 8),
                            const Text(
                              'Context refreshed for better replies ↺',
                              style: TextStyle(
                                fontSize: 12,
                                color: GemColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-banner')),
            ),

            if (buildHeader() != null) buildHeader()!,

            Expanded(child: _buildMessageList(ready)),

            if (buildExtraInput() != null) buildExtraInput()!,

            ChatInputBar(
              enabled: ready && !_loading,
              hint: inputHint,
              onSend: sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: moduleColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: moduleColor.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Icon(moduleIcon, size: 15, color: moduleColor),
          ),
          const SizedBox(width: 10),
          Text(
            moduleName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        if (_loading)
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, size: 22),
            color: GemColors.danger,
            tooltip: 'Stop generation',
            onPressed: stopGeneration,
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: GemColors.textSecondary,
            tooltip: 'New conversation',
            onPressed: () async => _initChat(clearHistory: true),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMessageList(bool ready) {
    if (!ready) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: GemColors.accent,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Model loading…',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return _EmptyState(
        color: moduleColor,
        icon: moduleIcon,
        name: moduleName,
        hints: emptyStateHints,
        onHintTap: sendMessage,
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (_, i) => ChatBubble(message: messages[i]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String name;
  final List<String> hints;
  final void Function(String) onHintTap;

  const _EmptyState({
    required this.color,
    required this.icon,
    required this.name,
    required this.hints,
    required this.onHintTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'On-device · Private · No internet',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            if (hints.isNotEmpty) ...[
              const SizedBox(height: 28),
              SuggestionChips(
                hints: hints,
                accent: color,
                onTap: onHintTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
