import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../core/gemma_service.dart';
import '../core/xml_parser.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/chat_bubble.dart';

class MedicScreen extends StatefulWidget {
  const MedicScreen({super.key});

  @override
  State<MedicScreen> createState() => _MedicScreenState();
}

class _MedicScreenState extends State<MedicScreen>
    with SingleTickerProviderStateMixin {
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: GemColors.medicColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: GemColors.medicColor.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.medical_services_outlined,
                    size: 15, color: GemColors.medicColor),
              ),
              const SizedBox(width: 10),
              const Text('Medic',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Chat'), Tab(text: 'First Aid')],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [
            _MedicChatTab(),
            _FirstAidTab(),
          ],
        ),
      ),
    );
  }
}

// MEDIC CHAT TAB

class _MedicChatTab extends StatefulWidget {
  const _MedicChatTab();

  @override
  State<_MedicChatTab> createState() => _MedicChatTabState();
}

class _MedicChatTabState extends State<_MedicChatTab> {
  // Local copy of the agentic loop - this screen predates BaseChatState and was not refactored.
  static const int _maxToolHops = 3;

  final List<ChatMessage> _messages = [];
  InferenceChat? _chat;
  bool _loading = false;
  final _scrollCtrl = ScrollController();

  static const _hints = [
    'Is paracetamol safe for children?',
    'Signs of dehydration',
    'CPR steps',
    'Symptoms of malaria?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initChat();
      final prefs = await SharedPreferences.getInstance();
      // Pref flag ensures the beta warning is shown at most once per install.
      if (!(prefs.getBool('medic_beta_warned') ?? false) && mounted) {
        await prefs.setBool('medic_beta_warned', true);
        if (mounted) _showBetaWarning();
      }
    });
  }

  void _showBetaWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: GemColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GemColors.warning.withValues(alpha: 0.4)),
            ),
            child: const Text('BETA',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: GemColors.warning,
                    letterSpacing: 1)),
          ),
          const SizedBox(width: 10),
          const Text('Medical Advisor',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GemColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GemColors.danger.withValues(alpha: 0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded,
                  size: 20, color: GemColors.danger.withValues(alpha: 0.8)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'This AI is NOT a substitute for professional medical advice. '
                  'Always consult a qualified doctor or healthcare provider for '
                  'diagnosis and treatment.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.white70, height: 1.5),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
            'This feature is under active development and may provide '
            'inaccurate information. Use for general reference only.',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.45), height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: GemColors.medicColor.withValues(alpha: 0.2),
                foregroundColor: GemColors.medicColor,
                side: BorderSide(color: GemColors.medicColor.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: const Text('I understand - continue',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _initChat() async {
    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) return;
    final c = await service.switchMission(Mission.medic);
    if (!mounted) return;
    setState(() {
      _chat = c;
      _messages.clear();
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

  // Agentic send (handles medical_search tool calls)
  Future<void> _sendText(String text) async {
    if (_chat == null || _loading) return;
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
        await _chat!.addQueryChunk(
            Message.text(text: nextPrompt, isUser: true));

        String buffer = '';
        bool toolDetected = false;

        await for (final event in _chat!.generateChatResponseAsync()) {
          if (event is! TextResponse) continue;
          buffer += event.token;

          if (!toolDetected) {
            final openIdx = buffer.indexOf(ToolParser.openTag);
            if (openIdx >= 0) {
              toolDetected = true;
              setState(() {
                _messages[_messages.length - 1] = ChatMessage(
                  text: '',
                  isUser: false,
                  isToolActive: true,
                  toolLabel: 'Searching medical knowledge…',
                );
              });
              continue;
            }
            final hold = ToolParser.trailingPartialOpenLength(buffer);
            final visible = hold == 0
                ? buffer
                : buffer.substring(0, buffer.length - hold);
            setState(() {
              _messages[_messages.length - 1] =
                  ChatMessage(text: visible, isUser: false);
            });
            _scrollToBottom();
          }
        }

        final call = toolDetected ? ToolParser.parse(buffer) : null;
        if (call == null) {
          setState(() {
            _messages[_messages.length - 1] = ChatMessage(
                text: ToolParser.stripCalls(buffer), isUser: false);
          });
          done = true;
        } else {
          setState(() {
            _messages[_messages.length - 1] = ChatMessage(
              text: '',
              isUser: false,
              isToolActive: true,
              toolLabel: ToolDispatcher.label(call.tool),
            );
          });
          final result = await ToolDispatcher.execute(call);
          nextPrompt = ToolParser.formatResponse(call.tool, result);
          setState(() {
            _messages[_messages.length - 1] =
                const ChatMessage(text: '', isUser: false, isLoading: true);
          });
          _scrollToBottom();
        }
      }

      if (!done) {
        setState(() {
          _messages[_messages.length - 1] = const ChatMessage(
            text:
                'I had trouble composing an answer. Please rephrase your question.',
            isUser: false,
          );
        });
      }
    } catch (e) {
      setState(() {
        if (_messages.isNotEmpty) _messages.removeLast();
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_chat == null || _loading) return;

    final source = await _showSourceDialog();
    if (source == null) return;

    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: source, imageQuality: 70); // 70 keeps size within model input constraints
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    await _sendImage(bytes);
  }

  Future<void> _sendImage(Uint8List bytes) async {
    if (_chat == null || _loading) return;

    setState(() {
      _messages.add(
          ChatMessage(text: 'Image uploaded', isUser: true, imageBytes: bytes));
      _messages
          .add(const ChatMessage(text: '', isUser: false, isLoading: true));
      _loading = true;
    });
    _scrollToBottom();

    const prompt =
        'Analyse this medicine or medical image. '
        'If it shows a medicine: identify the name, check expiry date if visible, '
        'list active ingredients if shown, state if prescription required, list warnings. '
        'If it shows a symptom or wound: describe what you see and give first-aid guidance.';

    try {
      await _chat!.addQueryChunk(
        Message.withImage(text: prompt, imageBytes: bytes, isUser: true),
      );

      String fullResponse = '';
      await for (final event in _chat!.generateChatResponseAsync()) {
        if (event is TextResponse) {
          fullResponse += event.token;
          setState(() {
            _messages[_messages.length - 1] =
                ChatMessage(text: fullResponse, isUser: false);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      setState(() {
        if (_messages.isNotEmpty) _messages.removeLast();
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
      });
    } finally {
      setState(() => _loading = false);
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
                  color: GemColors.medicColor),
              title: const Text('Camera',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: GemColors.medicColor),
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

    return Stack(
      children: [
        Column(
          children: [
            // Privacy badge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 16, color: GemColors.medicColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All analysis is local. No data leaves your device.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.65)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

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

            ChatInputBar(
              enabled: ready && !_loading,
              hint: 'Describe symptoms or ask about a medicine…',
              onSend: _sendText,
            ),
          ],
        ),

        // Camera FAB
        Positioned(
          bottom: 88,
          right: 20,
          child: FloatingActionButton(
            onPressed: ready && !_loading ? _pickAndSendImage : null,
            backgroundColor: ready && !_loading
                ? GemColors.medicColor.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.08),
            elevation: 0,
            child: Icon(Icons.camera_alt_outlined,
                color: ready && !_loading ? Colors.white : GemColors.textHint),
          ),
        ),
      ],
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: GemColors.medicColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: GemColors.medicColor.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.medical_services_outlined,
                  size: 30, color: GemColors.medicColor),
            ),
            const SizedBox(height: 16),
            const Text('Medic',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text('Health guidance · Offline · Private',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45))),
            const SizedBox(height: 24),
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
                            color: GemColors.medicColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: GemColors.medicColor
                                    .withValues(alpha: 0.25),
                                width: 0.8),
                          ),
                          child: Text(h,
                              style: const TextStyle(
                                  fontSize: 13, color: GemColors.medicColor)),
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

// FIRST AID QUICK REFERENCE TAB

class _FirstAidTab extends StatelessWidget {
  const _FirstAidTab();

  static const _items = [
    _FirstAidItem(
      title: 'CPR',
      icon: Icons.favorite_outlined,
      color: GemColors.danger,
      steps: [
        'Check scene is safe. Confirm unresponsiveness.',
        'Call emergency services immediately.',
        'Place heel of hand on centre of chest. Interlock fingers.',
        'Push hard and fast - 30 compressions at 100-120/min.',
        'Tilt head back, lift chin. Give 2 rescue breaths if trained.',
        'Continue 30:2 until help arrives or person recovers.',
      ],
    ),
    _FirstAidItem(
      title: 'Choking',
      icon: Icons.air,
      color: GemColors.warning,
      steps: [
        'Encourage strong coughs if person can cough.',
        'Stand behind them, lean them forward.',
        'Give up to 5 firm back blows between shoulder blades.',
        'If back blows fail: 5 abdominal thrusts (Heimlich).',
        'Alternate 5 back blows + 5 abdominal thrusts.',
        'Call emergency services if object doesn\'t dislodge.',
      ],
    ),
    _FirstAidItem(
      title: 'Burns',
      icon: Icons.local_fire_department_outlined,
      color: Color(0xFFFF8C42),
      steps: [
        'Cool under cool running water for 20 minutes.',
        'Do NOT use ice, butter, or toothpaste.',
        'Remove jewellery - NOT clothing stuck to skin.',
        'Cover loosely with cling film or clean cloth.',
        'Do NOT burst blisters.',
        'Seek help for burns larger than a palm, or on face/hands/joints.',
      ],
    ),
    _FirstAidItem(
      title: 'Snake Bite',
      icon: Icons.warning_amber_rounded,
      color: GemColors.success,
      steps: [
        'Move away from snake. Do not try to catch it.',
        'Keep person calm and still.',
        'Remove tight clothing/jewellery near bite.',
        'Keep bitten limb below heart level.',
        'Do NOT cut bite, suck venom, or apply ice.',
        'Get to hospital with anti-venom as fast as possible.',
      ],
    ),
    _FirstAidItem(
      title: 'Fracture',
      icon: Icons.accessibility_new_rounded,
      color: GemColors.iceBlue,
      steps: [
        'Do not attempt to straighten the bone.',
        'Immobilise limb in position found using a splint.',
        'Apply padding around the injury for support.',
        'Treat for shock: keep warm and calm.',
        'Do not give food or water.',
        'Seek emergency care immediately.',
      ],
    ),
    _FirstAidItem(
      title: 'Fever Management',
      icon: Icons.thermostat_rounded,
      color: GemColors.medicColor,
      steps: [
        'Keep person in cool, ventilated room.',
        'Give plenty of fluids (water, ORS).',
        'Paracetamol (age-appropriate dose) reduces fever safely.',
        'Do NOT use aspirin for children under 16.',
        'Sponge with lukewarm water if temperature is very high.',
        'Seek care if fever >39°C lasts >3 days, or with rash/stiff neck.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _FirstAidCard(item: _items[i]),
    );
  }
}

class _FirstAidItem {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> steps;

  const _FirstAidItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.steps,
  });
}

class _FirstAidCard extends StatefulWidget {
  final _FirstAidItem item;

  const _FirstAidCard({required this.item});

  @override
  State<_FirstAidCard> createState() => _FirstAidCardState();
}

class _FirstAidCardState extends State<_FirstAidCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: item.color.withValues(alpha: 0.25), width: 0.8),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 20, color: item.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: item.color.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: item.steps.asMap().entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            margin:
                                const EdgeInsets.only(right: 10, top: 1),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${e.key + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.color,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color:
                                    Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
