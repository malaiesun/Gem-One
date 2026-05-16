import 'package:flutter/material.dart';
import '../core/theme_prefs.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;

  const AnimatedGradientBackground({super.key, required this.child});

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true); // reverse:true creates ping-pong without a completion callback
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    // Listens here rather than via a provider because this widget reacts to
    // accent changes independently of its subtree's build cycle.
    ThemePrefs.instance.addListener(_onTheme);
  }

  @override
  void dispose() {
    ThemePrefs.instance.removeListener(_onTheme);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTheme() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final accent = ThemePrefs.instance.accent;
    // 6-9% lerp keeps the accent tint subtle enough not to wash out the dark background.
    final stop1 = Color.lerp(const Color(0xFF0D0B1E), accent, 0.06)!;
    final stop2 = Color.lerp(const Color(0xFF1A0A2E), accent, 0.09)!;
    final stop3 = Color.lerp(const Color(0xFF0D1B3E), accent, 0.05)!;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(stop1, stop2, _anim.value)!,
                Color.lerp(stop2, stop3, _anim.value)!,
                Color.lerp(stop3, stop1, _anim.value)!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
