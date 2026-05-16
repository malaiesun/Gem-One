import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/theme_prefs.dart';
import '../widgets/animated_background.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  String? _gender; // 'male' | 'female' | 'other'
  Color _accent = ThemePrefs.palette.first.color;
  bool _saving = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Guard prevents a double-tap race condition from writing prefs twice.
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    setState(() => _saving = true);

    await ThemePrefs.instance.setAccent(_accent);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name.isEmpty ? 'Friend' : name); // fallback keeps greeting non-empty
    await prefs.setString('user_gender', _gender ?? 'other');
    await prefs.setBool('onboarding_done', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo mark
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: GemColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: GemColors.accent.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 28, color: GemColors.accent),
                  ),
                  const SizedBox(height: 28),

                  // Title
                  Text(
                    'Welcome to\nGem One',
                    style: GoogleFonts.orbitron(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your private, offline AI companion.\nNo internet. No data leaving your device.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 44),

                  // Name field label
                  Text(
                    'What should I call you?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _NameField(controller: _nameCtrl),
                  const SizedBox(height: 32),

                  // Gender label
                  Text(
                    'How do you identify?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _GenderChips(
                    selected: _gender,
                    onSelect: (g) => setState(() => _gender = g),
                  ),
                  const SizedBox(height: 32),

                  // Theme color label
                  Text(
                    'Pick your accent color',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ColorPicker(
                    selected: _accent,
                    onSelect: (c) => setState(() => _accent = c),
                  ),
                  const SizedBox(height: 40),

                  // CTA
                  SizedBox(
                    width: double.infinity,
                    child: _saving
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: GemColors.accent,
                              strokeWidth: 2,
                            ),
                          )
                        : GestureDetector(
                            onTap: _finish,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    GemColors.accent,
                                    Color(0xFF7B61FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: GemColors.accent.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'You can change this later in Settings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  const _NameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 15, color: Colors.white),
        cursorColor: GemColors.accent,
        decoration: InputDecoration(
          hintText: 'Enter your name (optional)',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final Color selected;
  final void Function(Color) onSelect;

  const _ColorPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ThemePrefs.palette.map((entry) {
        final isSelected = selected == entry.color;
        return GestureDetector(
          onTap: () => onSelect(entry.color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: entry.color.withValues(alpha: 0.55), blurRadius: 12)]
                  : [],
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.black54)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _GenderChips extends StatelessWidget {
  final String? selected;
  final void Function(String) onSelect;

  const _GenderChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const options = [
      ('male', 'Male', Icons.male_rounded),
      ('female', 'Female', Icons.female_rounded),
      ('other', 'Prefer not to say', Icons.person_outline_rounded),
    ];

    return Row(
      children: options.map((opt) {
        final (value, label, icon) = opt;
        final isSelected = selected == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? GemColors.accent.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? GemColors.accent.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? GemColors.accent
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? GemColors.accent
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
