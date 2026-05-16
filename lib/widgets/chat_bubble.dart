import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../core/theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isLoading;
  final bool isToolActive;
  final String? toolLabel;
  final Uint8List? imageBytes;
  final bool useMath;
  // True while tokens are still streaming - renders plain text for performance.
  // Switches to markdown/LaTeX once the full response is ready.
  final bool isStreaming;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.isToolActive = false,
    this.toolLabel,
    this.imageBytes,
    this.useMath = false,
    this.isStreaming = false,
  });
}

class ChatBubble extends StatefulWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isUser = msg.isUser;

    return FadeTransition(
      opacity: _anim,
      child: SizeTransition(
        sizeFactor: _anim,
        axisAlignment: -1, // expands from the top edge rather than the center

        child: Padding(
          padding: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isUser ? 48 : 0,
            right: isUser ? 0 : 48,
          ),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: GestureDetector(
              onLongPress: msg.isLoading
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: msg.text));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
              child: _buildBubble(msg, isUser),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, bool isUser) {
    // Tool active indicator
    if (msg.isToolActive && !isUser) {
      return _ToolActiveBubble(label: msg.toolLabel ?? 'Tool');
    }

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 18),
    );

    final bgColor = isUser
        ? GemColors.accent.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.06);

    final borderColor = isUser
        ? GemColors.accent.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.1);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image thumbnail
          if (msg.imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                msg.imageBytes!,
                width: 180,
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
            if (msg.text.isNotEmpty) const SizedBox(height: 8),
          ],

          // Loading indicator
          if (msg.isLoading)
            const _TypingIndicator()
          // Streaming: plain text (fast, avoids broken partial markdown)
          else if (msg.isStreaming && msg.text.isNotEmpty)
            SelectableText(
              msg.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            )
          // Final message: full markdown / LaTeX rendering
          else if (msg.text.isNotEmpty)
            msg.useMath
                ? _MixedContent(text: msg.text, isUser: isUser)
                : _MarkdownContent(text: msg.text, isUser: isUser),

          // Attribution for assistant messages
          if (!isUser && !msg.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 11, color: GemColors.textHint),
                  const SizedBox(width: 4),
                  const Text(
                    'Gemma 4',
                    style: TextStyle(fontSize: 10, color: GemColors.textHint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolActiveBubble extends StatefulWidget {
  final String label;
  const _ToolActiveBubble({required this.label});

  @override
  State<_ToolActiveBubble> createState() => _ToolActiveBubbleState();
}

class _ToolActiveBubbleState extends State<_ToolActiveBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GemColors.warning.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(
          color: GemColors.warning.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _spin,
            child: Icon(Icons.settings_rounded,
                size: 14, color: GemColors.warning),
          ),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              color: GemColors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownContent extends StatelessWidget {
  final String text;
  final bool isUser;

  const _MarkdownContent({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      selectable: true,
      builders: {'pre': _ScrollableCodeBuilder()},
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: isUser ? Colors.white : Colors.white.withValues(alpha: 0.9),
        ),
        strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        em: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        code: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          color: isUser ? Colors.white : GemColors.iceBlue,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        blockquote: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        listBullet: const TextStyle(color: Colors.white),
        h1: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        h2: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        h3: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}

class _ScrollableCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          code,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            color: GemColors.iceBlue,
          ),
        ),
      ),
    );
  }
}

class _MixedContent extends StatelessWidget {
  final String text;
  final bool isUser;

  const _MixedContent({required this.text, required this.isUser});

  // Static final so the regexes are compiled once and shared across all rebuilds.
  static final _blockRe = RegExp(r'\\\[([\s\S]*?)\\\]');
  static final _inlineRe = RegExp(r'\\\(([\s\S]*?)\\\)');

  @override
  Widget build(BuildContext context) {
    final textColor = isUser ? Colors.white : Colors.white.withValues(alpha: 0.9);
    final texStyle = TextStyle(fontSize: 15, color: textColor);

    // No LaTeX - fast path
    if (!text.contains(r'\(') && !text.contains(r'\[')) {
      return _MarkdownContent(text: text, isUser: isUser);
    }

    final widgets = <Widget>[];
    int lastEnd = 0;

    // First pass: find block math \[...\]
    final allMatches = <_Segment>[];
    for (final m in _blockRe.allMatches(text)) {
      allMatches.add(_Segment(start: m.start, end: m.end, content: m.group(1)!, isBlock: true));
    }
    for (final m in _inlineRe.allMatches(text)) {
      // Only add inline if it doesn't overlap with a block match
      final overlaps = allMatches.any((s) => s.isBlock && m.start >= s.start && m.end <= s.end);
      if (!overlaps) {
        allMatches.add(_Segment(start: m.start, end: m.end, content: m.group(1)!, isBlock: false));
      }
    }
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    for (final seg in allMatches) {
      // Text before this math segment
      if (seg.start > lastEnd) {
        final before = text.substring(lastEnd, seg.start).trim();
        if (before.isNotEmpty) {
          widgets.add(_MarkdownContent(text: before, isUser: isUser));
          widgets.add(const SizedBox(height: 4));
        }
      }

      // Math widget
      final mathWidget = _buildMath(seg.content, texStyle);
      if (seg.isBlock) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(child: mathWidget),
          ),
        );
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: mathWidget,
        ));
      }

      lastEnd = seg.end;
    }

    // Remaining text
    if (lastEnd < text.length) {
      final tail = text.substring(lastEnd).trim();
      if (tail.isNotEmpty) {
        widgets.add(const SizedBox(height: 4));
        widgets.add(_MarkdownContent(text: tail, isUser: isUser));
      }
    }

    if (widgets.isEmpty) {
      return _MarkdownContent(text: text, isUser: isUser);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildMath(String tex, TextStyle style) {
    try {
      return Math.tex(
        tex.trim(),
        textStyle: style,
        onErrorFallback: (err) => Text(tex, style: style),
      );
    } catch (_) {
      return Text(tex, style: style);
    }
  }
}

class _Segment {
  final int start;
  final int end;
  final String content;
  final bool isBlock;

  _Segment({required this.start, required this.end, required this.content, required this.isBlock});
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            // Triangle wave: rises linearly 0→1 for first half, falls 1→0 for second half.
            final opacity = (t < 0.5 ? t * 2 : 2 - t * 2).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GemColors.textSecondary.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

class ChatInputBar extends StatefulWidget {
  final bool enabled;
  final String hint;
  final void Function(String) onSend;
  final VoidCallback? onAttachImage;
  final VoidCallback? onVoiceInput;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.hint = 'Type a message...',
    this.onAttachImage,
    this.onVoiceInput,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _ctrl.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: GemColors.bg.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.onAttachImage != null) ...[
              _IconBtn(
                icon: Icons.image_outlined,
                onTap: widget.onAttachImage!,
                enabled: widget.enabled,
              ),
              const SizedBox(width: 6),
            ],
            if (widget.onVoiceInput != null) ...[
              _IconBtn(
                icon: Icons.mic_rounded,
                onTap: widget.onVoiceInput!,
                enabled: widget.enabled,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _ctrl,
                  enabled: widget.enabled,
                  maxLines: null,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.enabled ? widget.hint : 'Model loading...',
                    hintStyle: const TextStyle(
                        color: GemColors.textHint, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(active: _hasText && widget.enabled, onTap: _send),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _SendButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? GemColors.accent : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: active ? GemColors.accent : Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 20,
          color: active ? Colors.white : GemColors.textHint,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _IconBtn({required this.icon, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        child: Icon(icon, size: 20, color: GemColors.textSecondary),
      ),
    );
  }
}
