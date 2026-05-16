import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gemma_service.dart';
import '../core/theme.dart';
import '../widgets/animated_background.dart';
import 'scholar_lesson_screen.dart';

class ScholarCourse {
  final String id;
  final String title;
  final List<ScholarModule> modules;

  const ScholarCourse(
      {required this.id, required this.title, required this.modules});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'modules': modules.map((m) => m.toJson()).toList(),
      };

  factory ScholarCourse.fromJson(Map<String, dynamic> j) => ScholarCourse(
        id: j['id'] as String,
        title: j['title'] as String,
        modules: (j['modules'] as List)
            .map((m) => ScholarModule.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class ScholarModule {
  final int index;
  final String title;
  final List<ScholarLesson> lessons;

  const ScholarModule(
      {required this.index, required this.title, required this.lessons});

  Map<String, dynamic> toJson() => {
        'index': index,
        'title': title,
        'lessons': lessons.map((l) => l.toJson()).toList(),
      };

  factory ScholarModule.fromJson(Map<String, dynamic> j) => ScholarModule(
        index: j['index'] as int,
        title: j['title'] as String,
        lessons: (j['lessons'] as List)
            .map((l) => ScholarLesson.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}

class ScholarLesson {
  final String id;
  final String title;
  final String desc;
  final String moduleTitle;

  const ScholarLesson({
    required this.id,
    required this.title,
    required this.desc,
    required this.moduleTitle,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'desc': desc,
        'moduleTitle': moduleTitle,
      };

  factory ScholarLesson.fromJson(Map<String, dynamic> j) => ScholarLesson(
        id: j['id'] as String,
        title: j['title'] as String,
        desc: j['desc'] as String? ?? '',
        moduleTitle: j['moduleTitle'] as String? ?? '',
      );
}

// Public helpers used by learn_screen.dart for "Import to Scholar"

ScholarCourse? parseScholarCourseXml(String text, String fallback) {
  final cm = RegExp(r'<gem_course>([\s\S]*?)</gem_course>').firstMatch(text);
  if (cm == null) return null;
  final inner = cm.group(1)!;
  final title = RegExp(r'<title>([\s\S]*?)</title>')
          .firstMatch(inner)?.group(1)?.trim() ?? fallback;
  final modules = <ScholarModule>[];
  int mIdx = 0;
  for (final modM in RegExp(r'<module[^>]*>([\s\S]*?)</module>').allMatches(inner)) {
    mIdx++;
    final mi = modM.group(1)!;
    final modTitle = RegExp(r'<title>([\s\S]*?)</title>')
            .firstMatch(mi)?.group(1)?.trim() ?? 'Module $mIdx';
    final lessons = <ScholarLesson>[];
    int lIdx = 0;
    for (final lesM in RegExp(r'<lesson[^>]*>([\s\S]*?)</lesson>').allMatches(mi)) {
      lIdx++;
      final li = lesM.group(1)!;
      final lesTitle = RegExp(r'<title>([\s\S]*?)</title>')
              .firstMatch(li)?.group(1)?.trim() ?? 'Lesson $lIdx';
      final lesDesc = RegExp(r'<desc>([\s\S]*?)</desc>')
              .firstMatch(li)?.group(1)?.trim() ?? '';
      lessons.add(ScholarLesson(
        id: 'M${mIdx}_L$lIdx',
        title: lesTitle,
        desc: lesDesc,
        moduleTitle: modTitle,
      ));
    }
    if (lessons.isNotEmpty) {
      modules.add(ScholarModule(index: mIdx, title: modTitle, lessons: lessons));
    }
  }
  if (modules.isEmpty) return null;
  return ScholarCourse(
    id: '${title.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}',
    title: title,
    modules: modules,
  );
}

Future<void> saveScholarCourse(ScholarCourse course) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList('scholar_course_ids') ?? [];
  if (!ids.contains(course.id)) ids.add(course.id);
  await prefs.setStringList('scholar_course_ids', ids);
  await prefs.setString('scholar_course_${course.id}', jsonEncode(course.toJson()));
}

class ScholarScreen extends StatefulWidget {
  const ScholarScreen({super.key});

  @override
  State<ScholarScreen> createState() => _ScholarScreenState();
}

class _ScholarScreenState extends State<ScholarScreen> {
  List<ScholarCourse> _courses = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final prefs = await SharedPreferences.getInstance();

    // One-time migration: old versions stored a single course under 'scholar_course_v1';
    // new versions use per-course keys indexed by 'scholar_course_ids'.
    final legacy = prefs.getString('scholar_course_v1');
    if (legacy != null) {
      try {
        final c = ScholarCourse.fromJson(
            jsonDecode(legacy) as Map<String, dynamic>);
        final ids = prefs.getStringList('scholar_course_ids') ?? [];
        if (!ids.contains(c.id)) {
          ids.add(c.id);
          await prefs.setStringList('scholar_course_ids', ids);
          await prefs.setString('scholar_course_${c.id}', legacy);
        }
        await prefs.remove('scholar_course_v1');
      } catch (_) {}
    }

    final ids = prefs.getStringList('scholar_course_ids') ?? [];
    final courses = <ScholarCourse>[];
    for (final id in ids) {
      final raw = prefs.getString('scholar_course_$id');
      if (raw != null) {
        try {
          courses.add(ScholarCourse.fromJson(
              jsonDecode(raw) as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    if (mounted) setState(() { _courses = courses; _loaded = true; });
  }

  Future<void> _persistCourse(ScholarCourse course) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('scholar_course_ids') ?? [];
    if (!ids.contains(course.id)) ids.add(course.id);
    await prefs.setStringList('scholar_course_ids', ids);
    await prefs.setString('scholar_course_${course.id}',
        jsonEncode(course.toJson()));
  }

  Future<void> _deleteCourse(ScholarCourse course) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('scholar_course_ids') ?? [];
    ids.remove(course.id);
    await prefs.setStringList('scholar_course_ids', ids);
    await prefs.remove('scholar_course_${course.id}');
    if (mounted) {
      setState(() => _courses.removeWhere((c) => c.id == course.id));
    }
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCourseSheet(
        onCreated: (course) async {
          await _persistCourse(course);
          if (!mounted) return;
          setState(() => _courses.add(course));
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _CourseDetailScreen(course: course),
            ),
          );
        },
      ),
    );
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
                color: GemColors.scholarColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: GemColors.scholarColor.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.school_rounded,
                  size: 15, color: GemColors.scholarColor),
            ),
            const SizedBox(width: 10),
            const Text('Scholar',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateSheet,
          backgroundColor: GemColors.scholarColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('New Course',
              style: TextStyle(fontWeight: FontWeight.w600)),
          elevation: 0,
        ),
        body: !_loaded
            ? const Center(
                child: CircularProgressIndicator(
                    color: GemColors.scholarColor, strokeWidth: 2))
            : _courses.isEmpty
                ? _buildEmpty()
                : _buildList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 100),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: GemColors.scholarColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: GemColors.scholarColor.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.school_rounded, size: 36, color: GemColors.scholarColor),
        ),
        const SizedBox(height: 18),
        const Text('Your AI Tutor',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Text(
          'Tell Scholar what you want to learn and it builds a full personalized course - modules, lessons, and quizzes - entirely on-device.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5), height: 1.6),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _InfoPill(Icons.auto_awesome_rounded,     'AI Course Plan'),
            _InfoPill(Icons.menu_book_rounded,        'Step-by-step Lessons'),
            _InfoPill(Icons.quiz_rounded,             'Inline Quizzes'),
            _InfoPill(Icons.track_changes_rounded,    'Progress Tracking'),
            _InfoPill(Icons.translate_rounded,        'Any Topic or Language'),
            _InfoPill(Icons.lock_outline_rounded,     'Fully Offline'),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GemColors.scholarColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GemColors.scholarColor.withValues(alpha: 0.18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Try these to get started',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: GemColors.scholarColor.withValues(alpha: 0.8))),
            const SizedBox(height: 10),
            ...[
              'Python Programming',
              'World History',
              'Organic Chemistry',
              'Guitar Basics',
              'Machine Learning',
            ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: _showCreateSheet,
                child: Row(children: [
                  Icon(Icons.arrow_right_rounded,
                      size: 16, color: GemColors.scholarColor.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(t, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65))),
                ]),
              ),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _courses.length,
      itemBuilder: (_, i) => _CourseCard(
        course: _courses[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _CourseDetailScreen(course: _courses[i])),
        ),
        onDelete: () => _confirmDelete(_courses[i]),
      ),
    );
  }

  void _confirmDelete(ScholarCourse course) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Delete course?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'This will delete "${course.title}" and all progress.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55), fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _deleteCourse(course); },
              style: ElevatedButton.styleFrom(
                backgroundColor: GemColors.danger.withValues(alpha: 0.2),
                foregroundColor: GemColors.danger,
              ),
              child: const Text('Delete')),
        ],
      ),
    );
  }
}

// COURSE CARD (hub list item)

class _CourseCard extends StatelessWidget {
  final ScholarCourse course;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CourseCard({
    required this.course,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final totalLessons =
        course.modules.fold(0, (s, m) => s + m.lessons.length);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GemColors.scholarColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: GemColors.scholarColor.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: GemColors.scholarColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_tree_rounded,
                size: 22, color: GemColors.scholarColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  '${course.modules.length} modules - $totalLessons lessons',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: Colors.white.withValues(alpha: 0.3)),
        ]),
      ),
    );
  }
}

// CREATE COURSE SHEET

class _CreateCourseSheet extends StatefulWidget {
  final Future<void> Function(ScholarCourse) onCreated;
  const _CreateCourseSheet({required this.onCreated});

  @override
  State<_CreateCourseSheet> createState() => _CreateCourseSheetState();
}

class _CreateCourseSheetState extends State<_CreateCourseSheet> {
  final _ctrl = TextEditingController();
  final _contextCtrl = TextEditingController();
  bool _building = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    final topic = _ctrl.text.trim();
    if (topic.isEmpty) return;
    setState(() { _building = true; _error = null; });

    final service = GemmaServiceProvider.of(context);
    if (!service.isReady) {
      setState(() { _building = false; _error = 'AI model not ready yet.'; });
      return;
    }

    try {
      final extra = _contextCtrl.text.trim();
      final personalization = extra.isNotEmpty
          ? 'Learner context: $extra\nTailor the course difficulty, scope, and examples to this background.\n'
          : '';
      final prompt =
          'You are a course planner. Generate a structured course for: "$topic"\n'
          '$personalization'
          'Output ONLY this XML, no other text:\n'
          '<gem_course>\n'
          '<title>Course Title</title>\n'
          '<module id="1"><title>Module Title</title>\n'
          '  <lesson id="1.1"><title>Lesson</title><desc>Short desc</desc></lesson>\n'
          '  <lesson id="1.2"><title>Lesson</title><desc>Short desc</desc></lesson>\n'
          '  <lesson id="1.3"><title>Lesson</title><desc>Short desc</desc></lesson>\n'
          '</module>\n'
          '</gem_course>\n'
          'RULES: EXACTLY 3 modules, EXACTLY 3 lessons each. Titles under 6 words. Descriptions under 10 words.';

      final reply = await service.quickReply(prompt);
      final course = parseScholarCourseXml(reply, topic);
      if (course == null) {
        setState(() { _building = false; _error = 'Could not parse course. Try again.'; });
        return;
      }
      await widget.onCreated(course);
    } catch (e) {
      if (mounted) setState(() { _building = false; _error = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0D22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: GemColors.scholarColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 18, color: GemColors.scholarColor),
            const SizedBox(width: 8),
            const Text('New Course',
                style: TextStyle(
                    fontSize: 16,
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
          const SizedBox(height: 6),
          Text(
            'What do you want to learn?',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GemColors.scholarColor.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Python, Guitar, Linear Algebra...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Any prior knowledge or specific focus? (optional)',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.38)),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GemColors.scholarColor.withValues(alpha: 0.18)),
            ),
            child: TextField(
              controller: _contextCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'e.g. I know basic Python · Focus on web dev · Beginner level',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
              onSubmitted: (_) => _build(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              'Python', 'Calculus', 'World History',
              'Guitar', 'Machine Learning', 'Organic Chemistry',
            ].map((t) => GestureDetector(
              onTap: () => setState(() => _ctrl.text = t),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: GemColors.scholarColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: GemColors.scholarColor.withValues(alpha: 0.18)),
                ),
                child: Text(t,
                    style: TextStyle(
                        fontSize: 11,
                        color: GemColors.scholarColor.withValues(alpha: 0.85))),
              ),
            )).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    fontSize: 12, color: GemColors.danger)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _building ? null : _build,
              icon: _building
                  ? const SizedBox(
                      width: 15, height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded, size: 17),
              label: Text(_building
                  ? 'Building your course...'
                  : 'Build Course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _building
                    ? GemColors.scholarColor.withValues(alpha: 0.2)
                    : GemColors.scholarColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// COURSE DETAIL SCREEN (single course map)

class _CourseDetailScreen extends StatefulWidget {
  final ScholarCourse course;
  const _CourseDetailScreen({required this.course});

  @override
  State<_CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<_CourseDetailScreen> {
  Map<String, bool> _lessonDone = {};

  @override
  void initState() {
    super.initState();
    _loadDone();
  }

  String _doneKey(String lesId) =>
      'scholar_done_${widget.course.id}_$lesId';

  Future<void> _loadDone() async {
    final prefs = await SharedPreferences.getInstance();
    final done = <String, bool>{};
    for (final mod in widget.course.modules) {
      for (final les in mod.lessons) {
        done[les.id] = prefs.getBool(_doneKey(les.id)) ?? false;
      }
    }
    if (mounted) setState(() => _lessonDone = done);
  }

  Future<void> _markDone(String lesId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey(lesId), true);
    if (mounted) setState(() => _lessonDone[lesId] = true);
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final doneCount = _lessonDone.values.where((v) => v).length;
    final totalCount = _lessonDone.length;

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(course.title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('$doneCount / $totalCount lessons done',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45))),
            ],
          ),
          centerTitle: true,
        ),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final mod = course.modules[i];
                    final done = mod.lessons
                        .where((l) => _lessonDone[l.id] ?? false)
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ModuleCard(
                        module: mod,
                        doneCount: done,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _ModulePathScreen(
                                course: course,
                                module: mod,
                                lessonDone: _lessonDone,
                                onLessonComplete: (lesId) async {
                                  await _markDone(lesId);
                                },
                              ),
                            ),
                          );
                          await _loadDone();
                        },
                      ),
                    );
                  },
                  childCount: course.modules.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// MODULE CARD

class _ModuleCard extends StatelessWidget {
  final ScholarModule module;
  final int doneCount;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.doneCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total    = module.lessons.length;
    final progress = doneCount / total;
    final isDone   = doneCount >= total;
    final started  = doneCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDone
              ? GemColors.success.withValues(alpha: 0.07)
              : started
                  ? GemColors.scholarColor.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? GemColors.success.withValues(alpha: 0.3)
                : started
                    ? GemColors.scholarColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: GemColors.scholarColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('${module.index}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: GemColors.scholarColor)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Row(children: [
                  Text('$doneCount / $total',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(isDone
                            ? GemColors.success.withValues(alpha: 0.8)
                            : GemColors.scholarColor.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isDone
                ? Icons.check_circle_rounded
                : Icons.chevron_right_rounded,
            size: 22,
            color: isDone
                ? GemColors.success.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.35),
          ),
        ]),
      ),
    );
  }
}

// MODULE PATH SCREEN (Duolingo-style nodes)

class _ModulePathScreen extends StatefulWidget {
  final ScholarCourse course;
  final ScholarModule module;
  final Map<String, bool> lessonDone;
  final Future<void> Function(String lesId) onLessonComplete;

  const _ModulePathScreen({
    required this.course,
    required this.module,
    required this.lessonDone,
    required this.onLessonComplete,
  });

  @override
  State<_ModulePathScreen> createState() => _ModulePathScreenState();
}

class _ModulePathScreenState extends State<_ModulePathScreen> {
  late Map<String, bool> _done;

  @override
  void initState() {
    super.initState();
    _done = Map.from(widget.lessonDone);
  }

  void _openLesson(ScholarLesson lesson) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScholarLessonScreen(
          course: widget.course,
          lesson: lesson,
          onComplete: () async {
            await widget.onLessonComplete(lesson.id);
            if (mounted) setState(() => _done[lesson.id] = true);
          },
        ),
      ),
    );
  }

  void _showNodePopup(BuildContext ctx, ScholarLesson lesson, Offset globalPos) {
    final screen = MediaQuery.of(ctx).size;
    const popupW = 240.0;
    const popupH = 160.0;
    final left = (globalPos.dx - popupW / 2).clamp(12.0, screen.width - popupW - 12);
    // Flip popup above the node when it would overflow the bottom of the screen.
    final top  = globalPos.dy + popupH + 60 < screen.height
        ? globalPos.dy + 44
        : globalPos.dy - popupH - 16;

    final isDone = _done[lesson.id] ?? false;

    // showGeneralDialog (not showDialog) is used because it supports arbitrary
    // pixel positioning via Positioned, which showDialog does not allow.
    showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      pageBuilder: (dctx, _, __) => Stack(children: [
        Positioned(
          left: left,
          top: top,
          width: popupW,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: GemColors.scholarColor.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(lesson.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3)),
                if (lesson.desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(lesson.desc,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45))),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dctx);
                      _openLesson(lesson);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          GemColors.scholarColor.withValues(alpha: 0.2),
                      foregroundColor: GemColors.scholarColor,
                      side: BorderSide(
                          color: GemColors.scholarColor.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      elevation: 0,
                    ),
                    child: Text(
                      isDone ? 'Practice Again' : 'Start Lesson',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 160),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessons = widget.module.lessons;
    final done = lessons.where((l) => _done[l.id] ?? false).length;

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(widget.module.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text('$done / ${lessons.length} lessons',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45))),
            ],
          ),
          centerTitle: true,
        ),
        body: LayoutBuilder(
          builder: (ctx, constraints) {
            final path = _ScholarNodePath(
              lessons:   lessons,
              lessonDone: _done,
              onTap: (lesson, globalPos) =>
                  _showNodePopup(ctx, lesson, globalPos),
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 80),
              child: Center(child: path),
            );
          },
        ),
      ),
    );
  }
}

// NODE PATH WIDGET

class _ScholarNodePath extends StatelessWidget {
  final List<ScholarLesson> lessons;
  final Map<String, bool> lessonDone;
  final void Function(ScholarLesson, Offset) onTap;

  static const double _nodeSize = 56;
  static const double _rowH = 96;
  static const double _sideX = 70;

  const _ScholarNodePath({
    required this.lessons,
    required this.lessonDone,
    required this.onTap,
  });

  List<Offset> _positions(double width) {
    final cx = width / 2;
    return List.generate(lessons.length, (i) {
      final double x;
      switch (i % 4) {
        case 0: x = cx; break;
        case 1: x = cx + _sideX; break;
        case 2: x = cx; break;
        default: x = cx - _sideX; break;
      }
      return Offset(x, i * _rowH);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final positions = _positions(width);
    final totalH = lessons.length * _rowH + _nodeSize + 20;

    // Build stars map for painter
    final stars = <int, int>{};
    for (int i = 0; i < lessons.length; i++) {
      stars[i + 1] = (lessonDone[lessons[i].id] ?? false) ? 1 : 0;
    }

    return SizedBox(
      width: width,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter:
                  _ScholarPathPainter(positions, stars, _nodeSize),
            ),
          ),
          ...List.generate(lessons.length, (i) {
            final lesson  = lessons[i];
            final pos     = positions[i];
            final isDone  = lessonDone[lesson.id] ?? false;
            return Positioned(
              left: pos.dx - _nodeSize / 2,
              top:  pos.dy,
              child: _ScholarNode(
                index:   i + 1,
                title:   lesson.title,
                isDone:  isDone,
                nodeSize: _nodeSize,
                onTap: (globalPos) => onTap(lesson, globalPos),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// PATH PAINTER (smooth S-curves)

class _ScholarPathPainter extends CustomPainter {
  final List<Offset> positions;
  final Map<int, int> stars;
  final double nodeSize;

  const _ScholarPathPainter(this.positions, this.stars, this.nodeSize);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < positions.length - 1; i++) {
      final from  = Offset(positions[i].dx,     positions[i].dy + nodeSize);
      final to    = Offset(positions[i + 1].dx, positions[i + 1].dy);
      final dy    = to.dy - from.dy;
      // Control points at 42% of segment height produce an S-curve (Duolingo-style path).
      final ctrl1 = Offset(from.dx, from.dy + dy * 0.42);
      final ctrl2 = Offset(to.dx,   to.dy   - dy * 0.42);

      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, to.dx, to.dy);

      final done1 = (stars[i + 1] ?? 0) > 0;
      final done2 = (stars[i + 2] ?? 0) > 0;

      if (done1 && done2) {
        canvas.drawPath(
            path,
            Paint()
              ..strokeWidth = 10
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..color = GemColors.scholarColor.withValues(alpha: 0.12)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawPath(
            path,
            Paint()
              ..strokeWidth = 3
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..color = GemColors.scholarColor.withValues(alpha: 0.75));
      } else {
        _drawDashed(
            canvas,
            path,
            Paint()
              ..strokeWidth = 2.5
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.14));
      }
    }
  }

  // Flutter's Path API has no native dash support, so dashes are drawn manually
  // by extracting sub-paths at fixed intervals via path.computeMetrics().
  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 7.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double pos = 0;
      while (pos < metric.length) {
        final end = min(pos + dash, metric.length);
        canvas.drawPath(metric.extractPath(pos, end), paint);
        pos += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_ScholarPathPainter old) =>
      old.stars != stars || old.positions != positions;
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GemColors.scholarColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GemColors.scholarColor.withValues(alpha: 0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: GemColors.scholarColor),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: GemColors.scholarColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ScholarNode extends StatelessWidget {
  final int index;
  final String title;
  final bool isDone;
  final double nodeSize;
  final void Function(Offset globalPos) onTap;

  const _ScholarNode({
    required this.index,
    required this.title,
    required this.isDone,
    required this.nodeSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // GlobalKey per node to convert local center coordinates to screen-space
    // for accurate popup positioning in _showNodePopup.
    final key = GlobalKey();
    return GestureDetector(
      key: key,
      onTap: () {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(
                Offset(nodeSize / 2, nodeSize / 2)) ??
            Offset.zero;
        onTap(pos);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circle node
          Container(
            width: nodeSize,
            height: nodeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? GemColors.success.withValues(alpha: 0.2)
                  : GemColors.scholarColor.withValues(alpha: 0.18),
              border: Border.all(
                color: isDone
                    ? GemColors.success.withValues(alpha: 0.8)
                    : GemColors.scholarColor.withValues(alpha: 0.65),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDone ? GemColors.success : GemColors.scholarColor)
                      .withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      size: 24, color: GemColors.success)
                  : Text('$index',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GemColors.scholarColor)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 90,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
