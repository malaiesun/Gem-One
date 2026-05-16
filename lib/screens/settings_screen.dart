import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/theme_prefs.dart';
import '../core/gemma_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import 'base_chat_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name   = '';
  String _gender = 'other';
  bool   _busy   = false;

  @override
  void initState() {
    super.initState();
    _load();
    ThemePrefs.instance.addListener(_onTheme);
  }

  @override
  void dispose() {
    ThemePrefs.instance.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() => setState(() {});

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name   = prefs.getString('user_name')   ?? '';
      _gender = prefs.getString('user_gender') ?? 'other';
    });
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GemColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit name',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Your name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', result.isEmpty ? 'Friend' : result);
    if (mounted) setState(() => _name = result.isEmpty ? 'Friend' : result);
  }

  Future<void> _clearChatHistory() async {
    final ok = await _confirm(
      'Clear chat history',
      'All conversation history will be erased. This cannot be undone.',
      destructive: false,
    );
    if (!ok) return;
    // Must clear the static in-memory cache separately; prefs.clear() doesn't reach it.
    BaseChatState.clearHistory();
    if (mounted) {
      _snack('Chat history cleared.');
    }
  }

  Future<void> _resetAll() async {
    final ok = await _confirm(
      'Reset all data',
      'Your name, preferences, lesson progress, and chat history will all be erased. '
      'You will be returned to the Welcome screen.',
      destructive: true,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      BaseChatState.clearHistory();
      if (!mounted) return;
      // (_) => false predicate removes ALL routes so back-navigation after reset is impossible.
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body,
      {required bool destructive}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GemColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content:
            Text(body, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor:
                    destructive ? GemColors.danger : GemColors.accent),
            child: Text(destructive ? 'Reset' : 'Clear'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: GemColors.surface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final service = GemmaServiceProvider.of(context);
    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Settings',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        body: _busy
            ? const Center(
                child: CircularProgressIndicator(
                    color: GemColors.accent, strokeWidth: 2))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                children: [
                  _sectionHeader('Profile'),
                  GlassCard(
                    child: Column(children: [
                      _tile(
                        icon: Icons.person_outline_rounded,
                        label: 'Name',
                        value: _name.isEmpty ? 'Not set' : _name,
                        onTap: _editName,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.wc_rounded,
                        label: 'Gender',
                        value: _genderLabel(_gender),
                        onTap: _editGender,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('Appearance'),
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.palette_outlined,
                                size: 18, color: GemColors.accent),
                            const SizedBox(width: 14),
                            const Text('Accent color',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white)),
                          ]),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: ThemePrefs.palette.map((entry) {
                              final isSelected =
                                  ThemePrefs.instance.accent == entry.color;
                              return GestureDetector(
                                onTap: () => ThemePrefs.instance.setAccent(entry.color),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: entry.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                                color: entry.color
                                                    .withValues(alpha: 0.55),
                                                blurRadius: 10)
                                          ]
                                        : [],
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded,
                                          size: 16, color: Colors.black54)
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('AI Model'),
                  GlassCard(
                    child: Column(children: [
                      _tile(
                        icon: Icons.memory_rounded,
                        label: 'Active model',
                        value: 'Gemma 4 E4B · LiteRT',
                        trailing: _statusDot(service.isReady),
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.storage_rounded,
                        label: 'Backend',
                        value: 'GPU (on-device)',
                      ),
                      _divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16,
                              color: GemColors.textSecondary.withValues(alpha: 0.7)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            'Model selection (E2B / 26MOE) coming in a future update.',
                            style: TextStyle(
                                fontSize: 12,
                                color: GemColors.textSecondary.withValues(alpha: 0.7),
                                height: 1.4),
                          )),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('Data & Privacy'),
                  GlassCard(
                    child: Column(children: [
                      _tile(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Clear chat history',
                        value: 'Erase all conversations',
                        onTap: _clearChatHistory,
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.delete_outline_rounded,
                        label: 'Reset all data',
                        value: 'Start fresh from onboarding',
                        onTap: _resetAll,
                        danger: true,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('About'),
                  GlassCard(
                    child: Column(children: [
                      _tile(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Gem One',
                        value: 'Version 1.0.0',
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.lock_outline_rounded,
                        label: 'Privacy',
                        value: '100% on-device · No data sent anywhere',
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.people_outline_rounded,
                        label: 'Purpose',
                        value: 'Built for rural communities',
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('Developer'),
                  GlassCard(
                    child: Column(children: [
                      _tile(
                        icon: Icons.person_rounded,
                        label: 'Malaiesun S.',
                        value: 'ECE Student · VIT Chennai',
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.school_rounded,
                        label: 'Institution',
                        value: 'Vellore Institute of Technology, Chennai',
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.language_rounded,
                        label: 'Website',
                        value: 'malaiesun.com',
                      ),
                      _divider(),
                      _tile(
                        icon: Icons.email_outlined,
                        label: 'Contact',
                        value: 'contact@malaiesun.com',
                      ),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: GemColors.textSecondary.withValues(alpha: 0.8))),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
    bool danger = false,
  }) {
    final color = danger ? GemColors.danger : GemColors.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 18, color: onTap != null || danger ? color : GemColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: danger ? GemColors.danger : Colors.white,
              )),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45))),
            ],
          )),
          if (trailing != null) trailing
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.white.withValues(alpha: 0.25)),
        ]),
      ),
    );
  }

  Widget _divider() => Divider(
      height: 1, thickness: 0.5, color: Colors.white.withValues(alpha: 0.07),
      indent: 48);

  Widget _statusDot(bool ready) {
    final color = ready ? GemColors.success : GemColors.warning;
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
      ),
    );
  }

  String _genderLabel(String g) {
    return switch (g) {
      'male'   => 'Male',
      'female' => 'Female',
      _        => 'Prefer not to say',
    };
  }

  Future<void> _editGender() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: GemColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Gender',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        children: [
          for (final opt in [
            ('male', 'Male', Icons.male_rounded),
            ('female', 'Female', Icons.female_rounded),
            ('other', 'Prefer not to say', Icons.person_outline_rounded),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, opt.$1),
              child: Row(children: [
                Icon(opt.$3, size: 20, color: GemColors.accent),
                const SizedBox(width: 12),
                Text(opt.$2,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                const Spacer(),
                if (_gender == opt.$1)
                  const Icon(Icons.check_rounded,
                      size: 16, color: GemColors.success),
              ]),
            ),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_gender', result);
    if (mounted) setState(() => _gender = result);
  }
}

