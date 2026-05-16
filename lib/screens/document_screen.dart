import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gemma_service.dart';
import '../core/theme.dart';
import '../widgets/animated_background.dart';

const String _docSystemPrompt = '''
IDENTITY: You are DocWriter, a professional document writing AI inside Gem One. Never say you are "Gemma", "Google", or "DeepMind".

YOUR JOB: Help the user create a polished, complete document.

STRICT WORKFLOW:
Step 1 - When the user describes a document they want, immediately identify EVERY detail you need to write it without placeholders. List ALL of them in ONE single message, numbered clearly. Do not ask one at a time.
  Example: "To write your letter I need:
  1. Your full name
  2. Your address
  3. The date to put on the letter
  4. Who it is addressed to
  5. The organization name
  Please provide all of these."

Step 2 - Wait for the user to provide all the details. If anything is still missing after they reply, ask the remaining ones together again in one message.

Step 3 - Once you have everything, write the complete document. Use only the information given. No placeholder text like [Name] or [Date]. If the user did not provide something optional, omit that section naturally. Write it as a real finished document.

Step 4 - Output the document inside these exact markers (no other text outside):
[DOCUMENT_START]
<the full document content, properly formatted>
[DOCUMENT_END]

RULES:
- Never use placeholder text in the final document.
- Never invent names, dates, or facts not given.
- Ask ALL questions at once, never one at a time.
- Write clean, professional prose appropriate to the document type.
- If images are described by the user (tagged as [IMAGE n: description]), refer to them naturally where relevant.
- Match the tone to the document type: formal for letters/reports, structured for CVs, flowing for essays.
''';

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  final List<_DocMsg> _messages = [];
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_AttachedImage> _pendingImages = [];

  InferenceChat? _chat;
  bool _loading = false;
  bool _chatReady = false;
  bool _docGenerated = false;
  int _pendingQuestionCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
      _maybeShowTour();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _maybeShowTour() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('doc_tour_done') ?? false) return;
    await prefs.setBool('doc_tour_done', true);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DocTourSheet(),
    );
  }

  Future<void> _initChat() async {
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) {
      setState(() {
        _messages.add(_DocMsg.bot(
            'The AI model is still loading. Please wait a moment.'));
      });
      return;
    }
    _chat = await service.switchMission(
      Mission.general,
      customPrompt: _docSystemPrompt,
    );
    if (!mounted) return;
    setState(() => _chatReady = true);
  }

  Future<void> _send() async {
    if (_loading || !_chatReady || _chat == null) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) return;

    _inputCtrl.clear();

    // Build user prompt with image descriptions appended
    String prompt = text;
    final imgs = List<_AttachedImage>.from(_pendingImages);
    if (imgs.isNotEmpty) {
      final descs = imgs
          .asMap()
          .entries
          .map((e) =>
              '[IMAGE ${e.key + 1}: ${e.value.description ?? "image attached"}]')
          .join('\n');
      prompt = text.isEmpty ? descs : '$text\n\n$descs';
    }

    setState(() {
      _messages.add(_DocMsg.user(text, images: imgs));
      _messages.add(_DocMsg.loading());
      _pendingImages.clear();
      _loading = true;
    });
    _scrollDown();

    try {
      // Send images directly to vision model so it can see them
      if (imgs.isNotEmpty) {
        await _chat!.addQueryChunk(
            Message.withImage(text: prompt, imageBytes: imgs.first.bytes, isUser: true));
        for (int i = 1; i < imgs.length; i++) {
          await _chat!.addQueryChunk(
              Message.withImage(text: '[IMAGE ${i + 1}]', imageBytes: imgs[i].bytes, isUser: true));
        }
      } else {
        await _chat!.addQueryChunk(Message.text(text: prompt, isUser: true));
      }
      final buf = StringBuffer();
      await for (final event in _chat!.generateChatResponseAsync()) {
        if (!mounted) break;
        if (event is TextResponse) buf.write(event.token);
      }
      final response = buf.toString().trim();
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(_DocMsg.bot(response));
      });
      _scrollDown();

      // If document was generated, compact context so AI only remembers the doc
      final ds = response.indexOf('[DOCUMENT_START]');
      final de = response.indexOf('[DOCUMENT_END]');
      if (ds >= 0 && de > ds) {
        final docContent =
            response.substring(ds + '[DOCUMENT_START]'.length, de).trim();
        setState(() => _docGenerated = true);
        await _resetChatWithDoc(docContent);
      }

      // Auto-show form if AI is asking a numbered question list
      final questions = _extractQuestions(response);
      if (questions != null && mounted) {
        setState(() => _pendingQuestionCount = questions.length);
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) _showQuestionForm(questions);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(_DocMsg.bot('Something went wrong: $e'));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Returns list of questions if the text contains 2+ numbered items.
  List<String>? _extractQuestions(String text) {
    final matches = RegExp(r'^\d+\.\s+(.+)$', multiLine: true)
        .allMatches(text)
        .map((m) => m.group(1)!.trim())
        .toList();
    return matches.length >= 2 ? matches : null;
  }

  void _showQuestionForm(List<String> questions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionFormSheet(
        questions: questions,
        onSubmit: (answers) {
          final buf = StringBuffer();
          for (int i = 0; i < questions.length; i++) {
            final a = answers[i].trim();
            if (a.isNotEmpty) buf.writeln('${i + 1}. $a');
          }
          final reply = buf.toString().trim();
          if (reply.isEmpty) return;
          _inputCtrl.text = reply;
          _send();
        },
      ),
    );
  }

  // Replaces the full conversation history with just the generated document so
  // subsequent edit requests don't overflow the 1024-token context window.
  Future<void> _resetChatWithDoc(String docText) async {
    if (!mounted) return;
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) return;
    _chat = await service.switchMission(
      Mission.general,
      customPrompt:
          'You are DocWriter. You have already written this document:\n'
          '[DOCUMENT_START]\n'
          '$docText\n'
          '[DOCUMENT_END]\n\n'
          'The user may ask for edits. When editing, output the FULL revised '
          'document inside [DOCUMENT_START] and [DOCUMENT_END] markers.',
    );
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

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final img = _AttachedImage(file: File(picked.path), bytes: bytes);
    setState(() => _pendingImages.add(img));
    if (!mounted) return;
    _showDescDialog(img);
  }

  void _showDescDialog(_AttachedImage img) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Describe this image',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. PCB schematic for ESP32 project',
            hintStyle:
                TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                  color: GemColors.docColor.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: GemColors.docColor),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          maxLines: 2,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Skip',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.docColor.withValues(alpha: 0.18),
              foregroundColor: GemColors.docColor,
            ),
            onPressed: () {
              img.description =
                  ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _markdownToPdf(String text, pw.Font font, pw.Font boldFont) {
    final widgets = <pw.Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith('# ')) {
        widgets.add(pw.Text(line.substring(2).trim(),
            style: pw.TextStyle(font: boldFont, fontSize: 18)));
        widgets.add(pw.SizedBox(height: 6));
      } else if (line.startsWith('## ')) {
        widgets.add(pw.Text(line.substring(3).trim(),
            style: pw.TextStyle(font: boldFont, fontSize: 14)));
        widgets.add(pw.SizedBox(height: 5));
      } else if (line.startsWith('### ')) {
        widgets.add(pw.Text(line.substring(4).trim(),
            style: pw.TextStyle(font: boldFont, fontSize: 12)));
        widgets.add(pw.SizedBox(height: 4));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        final content = _stripInlineMarkdown(line.substring(2).trim());
        widgets.add(pw.Text('• $content',
            style: pw.TextStyle(font: font, fontSize: 11.5, lineSpacing: 4)));
      } else if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 7));
      } else {
        widgets.add(pw.Text(_stripInlineMarkdown(line),
            style: pw.TextStyle(font: font, fontSize: 11.5, lineSpacing: 4.5)));
      }
    }
    return widgets;
  }

  String _stripInlineMarkdown(String s) =>
      s.replaceAllMapped(RegExp(r'\*{1,2}(.+?)\*{1,2}'), (m) => m.group(1)!)
       .replaceAllMapped(RegExp(r'_(.+?)_'), (m) => m.group(1)!);

  Future<void> _exportPdf(String docText, List<_AttachedImage> images) async {
    final doc      = pw.Document();
    final font     = await PdfGoogleFonts.nunitoRegular();
    final boldFont = await PdfGoogleFonts.nunitoBold();

    final imgWidgets = <pw.Widget>[];
    for (int i = 0; i < images.length; i++) {
      try {
        final pdfImg = pw.MemoryImage(images[i].bytes);
        imgWidgets.add(pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(pdfImg,
                width: double.infinity,
                height: 220,
                fit: pw.BoxFit.contain),
            if (images[i].description != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'Figure ${i + 1}: ${images[i].description!}',
                style: pw.TextStyle(
                    font: font, fontSize: 9, color: PdfColors.grey600),
              ),
            ],
            pw.SizedBox(height: 16),
          ],
        ));
      } catch (_) {}
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 56),
        build: (ctx) => [
          ..._markdownToPdf(docText, font, boldFont),
          if (imgWidgets.isNotEmpty) ...[
            pw.SizedBox(height: 28),
            pw.Text('Attachments',
                style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 13,
                    color: PdfColors.grey800)),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            ...imgWidgets,
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    if (!mounted) return;
    await Printing.sharePdf(bytes: bytes, filename: 'document.pdf');
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
                color: GemColors.docColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: GemColors.docColor.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.description_rounded,
                  size: 15, color: GemColors.docColor),
            ),
            const SizedBox(width: 10),
            const Text('DocWriter',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              color: Colors.white.withValues(alpha: 0.4),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _DocTourSheet(),
              ),
            ),
          ],
        ),
        body: Column(children: [
          Expanded(child: _buildMessages()),
          if (_pendingImages.isNotEmpty) _buildPendingImages(),
          _buildInput(),
        ]),
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.description_rounded,
                size: 52,
                color: GemColors.docColor.withValues(alpha: 0.28)),
            const SizedBox(height: 16),
            Text(
              'Tell me what you\'d like to create',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'e.g. "Write a resignation letter" · "Draft a CV" · "Formal complaint letter"\n'
              'I\'ll ask for everything I need, then write it for you.',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.38),
                  height: 1.6),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(_DocMsg msg) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 48,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor:
                  const AlwaysStoppedAnimation(GemColors.docColor),
              minHeight: 2,
            ),
          ),
        ),
      );
    }

    // Parse document out of bot message
    String? docText;
    String displayText = msg.text;
    List<_AttachedImage> docImages = [];

    if (!msg.isUser) {
      final ds = msg.text.indexOf('[DOCUMENT_START]');
      final de = msg.text.indexOf('[DOCUMENT_END]');
      if (ds >= 0) {
        docImages = _messages
            .where((m) => m.isUser && m.images.isNotEmpty)
            .expand((m) => m.images)
            .toList();
        if (de > ds) {
          docText = msg.text.substring(ds + '[DOCUMENT_START]'.length, de).trim();
          final before = msg.text.substring(0, ds).trim();
          final after  = msg.text.substring(de + '[DOCUMENT_END]'.length).trim();
          displayText = [before, after].where((s) => s.isNotEmpty).join('\n\n');
        } else {
          // Model hit token limit before [DOCUMENT_END] - treat rest as doc
          docText = msg.text.substring(ds + '[DOCUMENT_START]'.length).trim();
          displayText = msg.text.substring(0, ds).trim();
        }
      }
    }

    final isUser = msg.isUser;

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // User image thumbnails
        if (isUser && msg.images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: msg.images.map((img) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(img.file,
                    width: 64, height: 64, fit: BoxFit.cover),
              )).toList(),
            ),
          ),

        // Chat bubble
        if (displayText.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.84),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isUser
                  ? GemColors.docColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser
                    ? GemColors.docColor.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: isUser
                ? SelectableText(
                    displayText,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.55),
                  )
                : MarkdownBody(
                    data: displayText,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9), height: 1.55),
                      h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      h2: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      h3: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                      strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      em: TextStyle(fontStyle: FontStyle.italic, color: Colors.white.withValues(alpha: 0.85)),
                      listBullet: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                      code: TextStyle(fontSize: 12, color: GemColors.docColor, backgroundColor: Colors.white.withValues(alpha: 0.08), fontFamily: 'monospace'),
                    ),
                  ),
          ),

        // Document attachment card
        if (docText != null) ...[
          const SizedBox(height: 4),
          _DocumentCard(
            docText: docText,
            images: docImages,
            onExport: () => _exportPdf(docText!, docImages),
          ),
        ],

        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildPendingImages() {
    return Container(
      height: 68,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingImages.length,
        itemBuilder: (ctx, i) {
          final img = _pendingImages[i];
          return Stack(children: [
            Container(
              width: 56, height: 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                    image: FileImage(img.file), fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 2, right: 10,
              child: GestureDetector(
                onTap: () => setState(() => _pendingImages.remove(img)),
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.black54),
                  child: const Icon(Icons.close,
                      size: 10, color: Colors.white),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _generateNow() async {
    _inputCtrl.text =
        'Generate the document now using everything I have provided. '
        'Do not ask any more questions. Write the complete finished document.';
    await _send();
  }

  Widget _buildInput() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show only when AI has asked more than 2 questions and doc not yet generated
          if (_pendingQuestionCount > 2 && !_docGenerated && !_loading && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _chatReady ? _generateNow : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: GemColors.docColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: GemColors.docColor.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded,
                            size: 15, color: GemColors.docColor),
                        SizedBox(width: 6),
                        Text('Generate Now',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: GemColors.docColor)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Row(children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: GemColors.docColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: GemColors.docColor.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.attach_file_rounded,
                size: 20, color: GemColors.docColor),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _inputCtrl,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _chatReady
                    ? 'Describe what you want to create...'
                    : 'Loading AI...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: (_loading || !_chatReady) ? null : _send,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (_loading || !_chatReady)
                  ? Colors.white.withValues(alpha: 0.06)
                  : GemColors.docColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: GemColors.docColor.withValues(alpha: 0.5),
                    ),
                  )
                : const Icon(Icons.send_rounded,
                    size: 20, color: Colors.white),
          ),
        ),
          ]),
        ],
      ),
    );
  }
}

// DOCUMENT CARD (inline attachment)

class _DocumentCard extends StatelessWidget {
  final String docText;
  final List<_AttachedImage> images;
  final VoidCallback onExport;

  const _DocumentCard({
    required this.docText,
    required this.images,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84),
      decoration: BoxDecoration(
        color: GemColors.docColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: GemColors.docColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: GemColors.docColor.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              const Icon(Icons.description_rounded,
                  size: 16, color: GemColors.docColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Document',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: GemColors.docColor)),
              ),
              GestureDetector(
                onTap: onExport,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: GemColors.docColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: GemColors.docColor.withValues(alpha: 0.45)),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded,
                            size: 13, color: GemColors.docColor),
                        SizedBox(width: 5),
                        Text('Export PDF',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: GemColors.docColor)),
                      ]),
                ),
              ),
            ]),
          ),

          // Preview (first 8 lines)
          Padding(
            padding: const EdgeInsets.all(14),
            child: MarkdownBody(
              data: _preview(docText),
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75), height: 1.6),
                h1: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                h3: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                em: TextStyle(fontStyle: FontStyle.italic, color: Colors.white.withValues(alpha: 0.75)),
              ),
            ),
          ),

          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: images.map((img) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(img.file,
                      width: 52, height: 52, fit: BoxFit.cover),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _preview(String text) {
    final lines = text.split('\n');
    if (lines.length <= 8) return text;
    return '${lines.take(8).join('\n')}\n...';
  }
}

// DATA MODELS

class _DocMsg {
  final String text;
  final bool isUser;
  final bool isLoading;
  final List<_AttachedImage> images;

  const _DocMsg._({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.images = const [],
  });

  factory _DocMsg.user(String text, {List<_AttachedImage> images = const []}) =>
      _DocMsg._(text: text, isUser: true, images: images);

  factory _DocMsg.bot(String text) =>
      _DocMsg._(text: text, isUser: false);

  factory _DocMsg.loading() =>
      _DocMsg._(text: '', isUser: false, isLoading: true);
}

class _AttachedImage {
  final File file;
  final Uint8List bytes;
  String? description;

  _AttachedImage({required this.file, required this.bytes});
}

// TOUR SHEET

class _DocTourSheet extends StatelessWidget {
  const _DocTourSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: GemColors.docColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: GemColors.docColor.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.description_rounded,
              size: 30, color: GemColors.docColor),
        ),
        const SizedBox(height: 18),
        const Text('AI Document Writer',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(
          'Describe what you want to create. AI will ask for any missing details '
          'in one go, then write the complete document and attach it for download.',
          style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.65),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.docColor.withValues(alpha: 0.2),
              foregroundColor: GemColors.docColor,
              side: BorderSide(
                  color: GemColors.docColor.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: const Text('Got it',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// QUESTION FORM SHEET

class _QuestionFormSheet extends StatefulWidget {
  final List<String> questions;
  final void Function(List<String> answers) onSubmit;

  const _QuestionFormSheet({required this.questions, required this.onSubmit});

  @override
  State<_QuestionFormSheet> createState() => _QuestionFormSheetState();
}

class _QuestionFormSheetState extends State<_QuestionFormSheet> {
  late final List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
        widget.questions.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final answers = _ctrls.map((c) => c.text.trim()).toList();
    Navigator.pop(context);
    widget.onSubmit(answers);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0D22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: GemColors.docColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(children: [
              Icon(Icons.edit_note_rounded,
                  size: 18,
                  color: GemColors.docColor.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              const Text('Fill in the details',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.4)),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8 + bottom),
              itemCount: widget.questions.length,
              itemBuilder: (_, i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: GemColors.docColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: GemColors.docColor
                                        .withValues(alpha: 0.9))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(widget.questions[i],
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  height: 1.4)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _ctrls[i],
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        maxLines: 2,
                        minLines: 1,
                        textInputAction: i < widget.questions.length - 1
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: i < widget.questions.length - 1
                            ? (_) => FocusScope.of(context).nextFocus()
                            : (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Your answer...',
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.22),
                              fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: GemColors.docColor
                                    .withValues(alpha: 0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: GemColors.docColor
                                    .withValues(alpha: 0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: GemColors.docColor
                                    .withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GemColors.docColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                child: const Text('Submit Details',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
