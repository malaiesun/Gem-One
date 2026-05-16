import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../core/gemma_service.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];

  InferenceChat? _chat;

  bool _loading = false;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _initChat(),
    );
  }

  Future<void> _initChat() async {
    final service = GemmaServiceProvider.of(context);

    if (!service.isReady) return;

    final chat = await service.newChatSession();

    if (!mounted) return;

    setState(() {
      _chat = chat;
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

  // SEND TEXT

  Future<void> _sendText(String text) async {
    if (_chat == null || _loading) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
        ),
      );

      _messages.add(
        const ChatMessage(
          text: '',
          isUser: false,
          isLoading: true,
        ),
      );

      _loading = true;
    });

    _scrollToBottom();

    try {
      await _chat!.addQueryChunk(
        Message.text(
          text: text,
          isUser: true,
        ),
      );

      String fullResponse = '';

      await for (final event
          in _chat!.generateChatResponseAsync()) {
        if (event is TextResponse) {
          fullResponse += event.token;

          setState(() {
            _messages[_messages.length - 1] =
                ChatMessage(
              text: fullResponse,
              isUser: false,
            );
          });

          _scrollToBottom();
        }
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();

        _messages.add(
          ChatMessage(
            text: 'Error: $e',
            isUser: false,
          ),
        );

        _loading = false;
      });
    }
  }

  // IMAGE CHAT

  Future<void> _pickAndSendImage() async {
    if (_chat == null || _loading) return;

    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked == null) return;

    final bytes = await File(
      picked.path,
    ).readAsBytes();

    setState(() {
      _messages.add(
        const ChatMessage(
          text: '📷 Image uploaded',
          isUser: true,
        ),
      );

      _messages.add(
        const ChatMessage(
          text: '',
          isUser: false,
          isLoading: true,
        ),
      );

      _loading = true;
    });

    _scrollToBottom();

    try {
      await _chat!.addQueryChunk(
        Message.withImage(
          text: 'Describe this image in detail.',
          imageBytes: bytes,
          isUser: true,
        ),
      );

      String fullResponse = '';

      await for (final event
          in _chat!.generateChatResponseAsync()) {
        if (event is TextResponse) {
          fullResponse += event.token;

          setState(() {
            _messages[_messages.length - 1] =
                ChatMessage(
              text: fullResponse,
              isUser: false,
            );
          });

          _scrollToBottom();
        }
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();

        _messages.add(
          ChatMessage(
            text: 'Error: $e',
            isUser: false,
          ),
        );

        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = GemmaServiceProvider.of(context);

    final ready =
        service.isReady && _chat != null;

    return Scaffold(
      backgroundColor: GemColors.bg,

      appBar: AppBar(
        backgroundColor: GemColors.bg,

        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: GemColors.chatColor
                    .withValues(alpha: 0.15),
                borderRadius:
                    BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 15,
                color: GemColors.chatColor,
              ),
            ),

            const SizedBox(width: 10),

            const Text(
              'Assistant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: GemColors.textPrimary,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
            ),
            color: GemColors.textSecondary,
            onPressed: () async {
              setState(() {
                _messages.clear();
              });

              await _initChat();
            },
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      return ChatBubble(
                        message: _messages[i],
                      );
                    },
                  ),
          ),

          ChatInputBar(
            enabled: ready && !_loading,

            hint:
                'Ask anything or upload an image...',

            onSend: _sendText,

            onAttachImage:
                ready && !_loading
                    ? _pickAndSendImage
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: GemColors.chatColor
                    .withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 30,
                color: GemColors.chatColor,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'General Assistant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: GemColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Text chat · Image analysis · Fully private',
              style: TextStyle(
                fontSize: 12,
                color: GemColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}