import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../data/language_data.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import 'language_learn_screen.dart';
import 'scholar_screen.dart';

class LanguageHubScreen extends StatefulWidget {
  const LanguageHubScreen({super.key});

  @override
  State<LanguageHubScreen> createState() => _LanguageHubScreenState();
}

class _LanguageHubScreenState extends State<LanguageHubScreen> {
  Map<String, int> _xp = {};
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.toLowerCase().trim()));
    // postFrameCallback required because showModalBottomSheet needs the widget fully mounted.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowTour());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p  = await SharedPreferences.getInstance();
    final xp = <String, int>{};
    for (final l in kLanguages) {
      xp[l.code] = p.getInt('lang_${l.code}_xp') ?? 0;
    }
    if (mounted) setState(() => _xp = xp);
  }

  Future<void> _maybeShowTour() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('lang_tour_done') ?? false) return;
    await p.setBool('lang_tour_done', true);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LangTourSheet(),
    );
  }

  List<LangInfo> get _filtered {
    if (_query.isEmpty) return kLanguages;
    return kLanguages
        .where((l) =>
            l.name.toLowerCase().contains(_query) ||
            l.code.toLowerCase().contains(_query))
        .toList();
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
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: GemColors.polyglotColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: GemColors.polyglotColor.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.translate_rounded,
                  size: 15, color: GemColors.polyglotColor),
            ),
            const SizedBox(width: 10),
            const Text('Languages',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ]),
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline_rounded,
                  size: 20, color: Colors.white.withValues(alpha: 0.4)),
              tooltip: 'About Languages',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _LangTourSheet(),
              ),
            ),
          ],
        ),
        body: Column(children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 15, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search languages...',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.4)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.4)),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          Expanded(child: _buildGrid()),
        ]),
      ),
    );
  }

  Widget _buildGrid() {
    final langs = _filtered;
    if (langs.isEmpty) {
      return Center(
        child: Text('No languages found',
            style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.4))),
      );
    }

    return CustomScrollView(
      slivers: [
        // Scholar personalised-course banner - only shown when not searching
        if (_query.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScholarScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: GemColors.scholarColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GemColors.scholarColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: GemColors.scholarColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_rounded, size: 18, color: GemColors.scholarColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Want a personalised language course?',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Build it in Scholar - AI generates modules, lessons & quizzes for you.',
                            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45), height: 1.4)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios_rounded, size: 13, color: GemColors.scholarColor.withValues(alpha: 0.6)),
                  ]),
                ),
              ),
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _LangCard(
                lang: langs[i],
                xp:   _xp[langs[i].code] ?? 0,
                onTap: () => _open(context, langs[i]),
              ),
              childCount: langs.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, LangInfo lang) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LanguageLearnScreen(lang: lang)));
    _load();
  }
}

// LANGUAGE CARD

class _LangCard extends StatelessWidget {
  final LangInfo     lang;
  final int          xp;
  final VoidCallback onTap;

  const _LangCard(
      {required this.lang, required this.xp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasXp = xp > 0;
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(lang.flag, style: const TextStyle(fontSize: 28)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: GemColors.polyglotColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: GemColors.polyglotColor.withValues(alpha: 0.25)),
              ),
              child: const Text('AI',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: GemColors.polyglotColor)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(lang.name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 4),
          if (hasXp)
            Text('$xp XP earned',
                style: TextStyle(
                    fontSize: 11,
                    color: GemColors.polyglotColor.withValues(alpha: 0.9)))
          else
            Text('AI-generated lessons',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.3))),
        ]),
      ),
    );
  }
}

// FIRST-TIME LANGUAGE TOUR

class _LangTourSheet extends StatelessWidget {
  const _LangTourSheet();

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
        // Handle
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
            color: GemColors.polyglotColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: GemColors.polyglotColor.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.translate_rounded,
              size: 30, color: GemColors.polyglotColor),
        ),
        const SizedBox(height: 18),

        const Text('AI Language Learning',
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 10),

        Text(
          'Choose a language and the AI builds your lessons on-device. '
          'No internet, no pre-built content - every lesson is generated '
          'just for you based on your goal and progress.',
          style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.65),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: const [
            _Pill(Icons.flash_on_rounded,        'AI-Generated'),
            _Pill(Icons.mic_rounded,              'Speaking'),
            _Pill(Icons.extension_rounded,        'Fill Blanks'),
            _Pill(Icons.quiz_rounded,             'Quizzes'),
            _Pill(Icons.compare_arrows_rounded,   'Matching'),
            _Pill(Icons.auto_graph_rounded,       'Adapts to You'),
          ],
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.polyglotColor.withValues(alpha: 0.2),
              foregroundColor: GemColors.polyglotColor,
              side: BorderSide(
                  color: GemColors.polyglotColor.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: const Text('Start Learning',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GemColors.polyglotColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: GemColors.polyglotColor.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: GemColors.polyglotColor),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: GemColors.polyglotColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

