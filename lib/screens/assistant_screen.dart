import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../core/gemma_service.dart';
import '../core/xml_parser.dart';
import '../widgets/animated_background.dart';
import '../widgets/chat_bubble.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const int _maxToolHops = 3;

  final List<ChatMessage> _messages = [];
  InferenceChat? _chat;
  bool _loading = false;
  bool _cancelled = false;
  int _exchangeCount = 0;
  final _scrollCtrl = ScrollController();
  Uint8List? _pendingImage;

  static const _hints = [
    'Summarise this image',
    'Write a formal letter',
    'Explain a concept simply',
    'Help me with a decision',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  Future<void> _initChat() async {
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) return;
    final c = await service.switchMission(Mission.general);
    if (!mounted) return;
    setState(() {
      _chat = c;
      _messages.clear();
      _exchangeCount = 0;
    });
  }

  @override
  void dispose() {
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

  void _stopGeneration() {
    if (_loading) setState(() => _cancelled = true);
  }

  Future<void> _sendText(String text) async {
    if (_chat == null || _loading || !mounted) return;

    // _pendingImage stages the image; the user can still type a caption before sending both together.
    if (_pendingImage != null) {
      final img = _pendingImage!;
      setState(() => _pendingImage = null);
      await _sendImage(img, userText: text.isEmpty ? 'Describe this image in detail.' : text);
      return;
    }

    _cancelled = false;
    final service = GemmaServiceProvider.of(context);

    // Auto-reset after 6 exchanges to prevent KV-cache overflow.
    _exchangeCount++;
    if (_exchangeCount > 6) {
      final newChat = await service.switchMission(Mission.general);
      if (!mounted) return;
      setState(() {
        _chat = newChat;
        _exchangeCount = 1;
      });
    }

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(const ChatMessage(text: '', isUser: false, isLoading: true));
      _loading = true;
    });
    _scrollToBottom();

    try {
      String nextPrompt = text;
      bool done = false;

      for (int hop = 0; hop < _maxToolHops && !done; hop++) {
        if (!mounted) break;

        await _chat!.addQueryChunk(
            Message.text(text: nextPrompt, isUser: true));

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
              if (mounted) {
                setState(() {
                  _messages[_messages.length - 1] = ChatMessage(
                    text: '',
                    isUser: false,
                    isToolActive: true,
                    toolLabel: 'detecting…',
                  );
                });
              }
              continue;
            }
            final hold = ToolParser.trailingPartialOpenLength(buffer);
            final visible = hold == 0
                ? buffer
                : buffer.substring(0, buffer.length - hold);
            if (mounted) {
              setState(() {
                _messages[_messages.length - 1] =
                    ChatMessage(text: visible, isUser: false, isStreaming: true);
              });
              _scrollToBottom();
            }
          }
        }

        if (!mounted) break;
        if (_cancelled) {
          if (buffer.isNotEmpty && mounted) {
            setState(() {
              _messages[_messages.length - 1] =
                  ChatMessage(text: buffer.trim(), isUser: false);
            });
          }
          break;
        }

        final call = toolDetected ? ToolParser.parse(buffer) : null;
        if (call == null) {
          if (mounted) {
            setState(() {
              _messages[_messages.length - 1] = ChatMessage(
                text: ToolParser.stripCalls(buffer),
                isUser: false,
                isStreaming: false,
              );
            });
          }
          done = true;
        } else {
          if (mounted) {
            setState(() {
              _messages[_messages.length - 1] = ChatMessage(
                text: '',
                isUser: false,
                isToolActive: true,
                toolLabel: ToolDispatcher.label(call.tool),
              );
            });
          }
          final result = await ToolDispatcher.execute(call);
          if (!mounted) break;
          nextPrompt = ToolParser.formatResponse(call.tool, result);
          setState(() {
            _messages[_messages.length - 1] =
                const ChatMessage(text: '', isUser: false, isLoading: true);
          });
          _scrollToBottom();
        }
      }

      if (mounted && !done) {
        setState(() {
          _messages[_messages.length - 1] = const ChatMessage(
            text:
                'I had trouble composing a final answer. Please rephrase your question.',
            isUser: false,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty) _messages.removeLast();
          _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_chat == null || _loading) return;

    final source = await _showSourceDialog();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    // Stage image - user types a prompt before sending
    if (mounted) setState(() => _pendingImage = bytes);
  }

  Future<void> _sendImage(Uint8List bytes, {required String userText}) async {
    if (_chat == null || _loading) return;

    _cancelled = false;
    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true, imageBytes: bytes));
      _messages.add(const ChatMessage(text: '', isUser: false, isLoading: true));
      _loading = true;
    });
    _scrollToBottom();

    try {
      await _chat!.addQueryChunk(
        Message.withImage(text: userText, imageBytes: bytes, isUser: true),
      );

      String fullResponse = '';
      await for (final event in _chat!.generateChatResponseAsync()) {
        if (!mounted || _cancelled) break;
        if (event is TextResponse) {
          fullResponse += event.token;
          setState(() {
            _messages[_messages.length - 1] =
                ChatMessage(text: fullResponse, isUser: false, isStreaming: true);
          });
          _scrollToBottom();
        }
      }
      if (mounted) {
        setState(() {
          _messages[_messages.length - 1] =
              ChatMessage(text: fullResponse, isUser: false, isStreaming: false);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty) _messages.removeLast();
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<ImageSource?> _showSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: GemColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: GemColors.assistantColor),
              title: const Text('Camera',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: GemColors.assistantColor),
              title: const Text('Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = GemmaServiceProvider.of(context);
    final ready = service.isReady && _chat != null;

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
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
                  color: GemColors.assistantColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: GemColors.assistantColor.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 15, color: GemColors.assistantColor),
              ),
              const SizedBox(width: 10),
              const Text('Assistant',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
          actions: [
            if (_loading)
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, size: 22),
                color: GemColors.danger,
                tooltip: 'Stop generation',
                onPressed: _stopGeneration,
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: GemColors.textSecondary,
                tooltip: 'New conversation',
                onPressed: _initChat,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) =>
                          ChatBubble(message: _messages[i]),
                    ),
            ),
            if (_pendingImage != null) _buildImagePreview(),
            ChatInputBar(
              enabled: ready && !_loading,
              hint: _pendingImage != null ? 'Add a message (optional)…' : 'Ask anything…',
              onSend: _sendText,
              onAttachImage: ready && !_loading ? _pickAndSendImage : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: GemColors.bg.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(_pendingImage!, width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Image attached - type a message or send',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
            onPressed: () => setState(() => _pendingImage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
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
                color: GemColors.assistantColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: GemColors.assistantColor.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 32, color: GemColors.assistantColor),
            ),
            const SizedBox(height: 18),
            const Text('Assistant',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text('Text · Images · Fully offline',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45))),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _hints
                  .map((h) => GestureDetector(
                        onTap: () => _sendText(h),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: GemColors.assistantColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: GemColors.assistantColor.withValues(alpha: 0.25),
                                width: 0.8),
                          ),
                          child: Text(h,
                              style: const TextStyle(
                                  fontSize: 13, color: GemColors.assistantColor)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
