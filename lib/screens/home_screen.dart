import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/gemma_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/mission_card.dart';
import 'scholar_screen.dart';
import 'medic_screen.dart';
import 'learn_screen.dart';
import 'assistant_screen.dart';
import 'calculator_screen.dart';
import 'language_hub_screen.dart';
import 'reference_screen.dart';
import 'settings_screen.dart';
import 'document_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowTour());
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
    });
  }

  Future<void> _maybeShowTour() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('tour_done') ?? false) return;
    await prefs.setBool('tour_done', true);
    if (!mounted) return;
    _showTour();
  }

  void _showTour() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AppTourSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = GemmaServiceProvider.of(context);

    return AnimatedGradientBackground(
      child: AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  _buildHeader(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _ModelStatusCard(service: service),
                        const SizedBox(height: 20),
                        _buildLanguageHero(context),
                        const SizedBox(height: 12),
                        _buildDocumentCard(context, service),
                        const SizedBox(height: 12),
                        _buildScholarCard(context, service),
                        const SizedBox(height: 12),
                        _buildAssistantCard(context, service),
                        const SizedBox(height: 12),
                        _buildUtilityGrid(context, service),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildHeader() {
    final greeting = _greeting();
    final hasName = _userName.isNotEmpty && _userName != 'Friend';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GEM ONE',
                    style: GoogleFonts.orbitron(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasName ? '$greeting, $_userName' : greeting,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gemma All in One · Offline · Private',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.38),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
                    // Builder provides a descendant context so Navigator.push works
            // correctly when this widget is inside a Sliver (outer context is a Sliver).
            Builder(builder: (ctx) => IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              color: Colors.white.withValues(alpha: 0.45),
              tooltip: 'Settings',
              onPressed: () => _navigate(ctx, const SettingsScreen()),
            )),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildLanguageHero(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigate(context, const LanguageHubScreen()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: GemColors.polyglotColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: GemColors.polyglotColor.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: GemColors.polyglotColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: GemColors.polyglotColor.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.translate_rounded,
                size: 24, color: GemColors.polyglotColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Languages',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text(
                  '18 languages · AI lessons · Speaking & Quizzes',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14,
              color: GemColors.polyglotColor.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  Widget _buildUtilityGrid(BuildContext context, GemmaService service) {
    final ready = service.isReady;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      // Disables GridView's own scroll to avoid nested scroll conflict with the parent CustomScrollView.
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _MiniCard(
          title: 'Learn',
          subtitle: 'Study & Docs',
          icon: Icons.menu_book_rounded,
          accent: GemColors.studyColor,
          enabled: ready,
          onTap: () => _navigate(context, const LearnScreen()),
        ),
        _MiniCard(
          title: 'Medic',
          subtitle: 'Health',
          icon: Icons.medical_services_outlined,
          accent: GemColors.medicColor,
          enabled: ready,
          badge: 'Beta',
          onTap: () => _navigate(context, const MedicScreen()),
        ),
        _MiniCard(
          title: 'Calculator',
          subtitle: 'Basic & Scientific',
          icon: Icons.calculate_rounded,
          accent: GemColors.accent,
          enabled: true,
          badge: 'No AI',
          badgeColor: const Color(0xFF888899),
          onTap: () => _navigate(context, const CalculatorScreen()),
        ),
        _MiniCard(
          title: 'Reference',
          subtitle: 'First Aid · Maths',
          icon: Icons.auto_stories_rounded,
          accent: GemColors.referenceColor,
          enabled: true,
          badge: 'No AI',
          badgeColor: const Color(0xFF888899),
          onTap: () => _navigate(context, const ReferenceScreen()),
        ),
      ],
    );
  }

  Widget _buildScholarCard(BuildContext context, GemmaService service) {
    final ready = service.isReady;
    return GestureDetector(
      onTap: ready ? () => _navigate(context, const ScholarScreen()) : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: ready ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GemColors.scholarColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: GemColors.scholarColor.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: GemColors.scholarColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: GemColors.scholarColor.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.school_rounded,
                  size: 24,
                  color: ready
                      ? GemColors.scholarColor
                      : GemColors.scholarColor.withValues(alpha: 0.4)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scholar',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(
                    'AI-guided courses · Step-by-step lessons · Inline quizzes',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color: GemColors.scholarColor.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, GemmaService service) {
    final ready = service.isReady;
    return GestureDetector(
      onTap: ready ? () => _navigate(context, const DocumentScreen()) : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: GemColors.docColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GemColors.docColor.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: GemColors.docColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: GemColors.docColor.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.description_rounded,
                size: 24,
                color: ready
                    ? GemColors.docColor
                    : GemColors.docColor.withValues(alpha: 0.4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DocWriter',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text(
                  'AI writes letters, reports & CVs - asks you first, no placeholders',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14,
              color: GemColors.docColor.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  Widget _buildAssistantCard(BuildContext context, GemmaService service) {
    return MissionCard(
      title: 'Assistant',
      subtitle: 'General AI chat · Image analysis · Markdown',
      icon: Icons.chat_bubble_outline_rounded,
      accent: GemColors.assistantColor,
      enabled: service.isReady,
      fullWidth: true,
      onTap: () => _navigate(context, const AssistantScreen()),
    );
  }

  Future<void> _navigate(BuildContext context, Widget page) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutQuint)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    // Reload in case the user updated their name in Settings while navigated away.
    if (mounted) _loadUser();
  }
}

// MODEL STATUS CARD

class _ModelStatusCard extends StatelessWidget {
  final GemmaService service;
  const _ModelStatusCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final isReady  = service.status == ModelStatus.ready;
    final isError  = service.status == ModelStatus.error;
    final isLoading = !isReady && !isError;

    final dotColor = isReady
        ? GemColors.success
        : isError
            ? GemColors.danger
            : GemColors.warning;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Model info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gemma 4 E4B',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'LiteRT Backend · On-device',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Status dot
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isReady ? 'Ready' : isError ? 'Error' : 'Loading',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dotColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (isLoading) ...[
            const SizedBox(height: 12),
            Text(
              service.statusMessage,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(GemColors.accent),
              ),
            ),
          ],

          if (isError) ...[
            const SizedBox(height: 10),
            Text(
              service.errorMessage ?? service.statusMessage,
              style: const TextStyle(fontSize: 12, color: GemColors.danger),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => service.initialize(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: GemColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: GemColors.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: GemColors.danger,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// APP TOUR SHEET (shown once on first launch)

class _AppTourSheet extends StatefulWidget {
  const _AppTourSheet();

  @override
  State<_AppTourSheet> createState() => _AppTourSheetState();
}

class _AppTourSheetState extends State<_AppTourSheet> {
  int _page = 0;

  static const _pages = [
    _TourPage(
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF9D78FF),
      title: 'Welcome to Gem One',
      body:
          'Your private, offline AI companion. Everything runs on your device - no internet, no data sent anywhere.',
    ),
    _TourPage(
      icon: Icons.calculate_outlined,
      color: Color(0xFF74B9FF),
      title: 'Scholar',
      body:
          'Ask maths and science questions. Get step-by-step solutions, explanations, and worked examples.',
    ),
    _TourPage(
      icon: Icons.medical_services_outlined,
      color: Color(0xFF5EE7D0),
      title: 'Medic (Beta)',
      body:
          'General health guidance and first-aid reference. Not a replacement for a doctor - always consult a healthcare professional.',
    ),
    _TourPage(
      icon: Icons.menu_book_rounded,
      color: Color(0xFFFF9E64),
      title: 'Learn',
      body:
          'Upload or paste any document and the AI generates summaries, quizzes, and study material from your content.',
    ),
    _TourPage(
      icon: Icons.translate_rounded,
      color: Color(0xFFA8D8A8),
      title: 'Languages',
      body:
          'AI-generated language courses with flashcards, quizzes, matching, fill-in-the-blanks, and speaking practice.',
    ),
    _TourPage(
      icon: Icons.chat_bubble_outline_rounded,
      color: Color(0xFFB48EFF),
      title: 'Assistant',
      body:
          'General-purpose AI chat. Ask anything, analyse images, or get markdown-formatted answers.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final isLast = _page == _pages.length - 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: page.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: page.color.withValues(alpha: 0.3)),
          ),
          child: Icon(page.icon, size: 30, color: page.color),
        ),
        const SizedBox(height: 20),

        // Title
        Text(page.title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 10),

        // Body
        Text(page.body,
            style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.6),
            textAlign: TextAlign.center),
        const SizedBox(height: 28),

        // Dots
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(
          _pages.length,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _page
                  ? page.color
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        )),
        const SizedBox(height: 20),

        // Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (isLast) {
                Navigator.pop(context);
              } else {
                setState(() => _page++);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: page.color.withValues(alpha: 0.18),
              foregroundColor: page.color,
              side: BorderSide(color: page.color.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: Text(isLast ? 'Get Started' : 'Next',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _TourPage {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _TourPage(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});
}

// COMPACT MINI CARD (2x2 utility grid)

class _MiniCard extends StatelessWidget {
  final String       title;
  final String       subtitle;
  final IconData     icon;
  final Color        accent;
  final bool         enabled;
  final VoidCallback onTap;
  final String?      badge;
  final Color        badgeColor;

  const _MiniCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.enabled = true,
    this.badge,
    this.badgeColor = const Color(0xFFFFB347),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: badgeColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(badge!,
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                            letterSpacing: 0.3)),
                  ),
                ],
              ]),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.45),
                      height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
