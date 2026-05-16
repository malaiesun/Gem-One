import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../widgets/animated_background.dart';
import 'calculator_tools.dart';

enum _Cat { basic, finance, unit, health, everyday }

class _ToolDef {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final _Cat cat;
  final Widget Function() build;

  const _ToolDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cat,
    required this.build,
  });
}

const _catColors = {
  _Cat.basic:    GemColors.accent,
  _Cat.finance:  GemColors.studyColor,
  _Cat.unit:     GemColors.iceBlue,
  _Cat.health:   GemColors.medicColor,
  _Cat.everyday: GemColors.warning,
};

const _catLabels = {
  _Cat.basic:    'Basic',
  _Cat.finance:  'Finance',
  _Cat.unit:     'Unit',
  _Cat.health:   'Health',
  _Cat.everyday: 'Everyday',
};

final _tools = <_ToolDef>[
  _ToolDef(id:'basic',    title:'Calculator',          subtitle:'Standard arithmetic',            icon:Icons.calculate_rounded,           cat:_Cat.basic,    build:() => const _BasicCalcWidget()),
  _ToolDef(id:'sci',      title:'Scientific',          subtitle:'sin/cos/log/√/π',                icon:Icons.functions_rounded,           cat:_Cat.basic,    build:() => const _SciCalcWidget()),
  _ToolDef(id:'pct',      title:'Percentage',          subtitle:'X% of Y, increase/decrease',    icon:Icons.percent_rounded,             cat:_Cat.finance,  build:() => const PercentageCalc()),
  _ToolDef(id:'disc',     title:'Discount',            subtitle:'Sale price & savings',           icon:Icons.local_offer_outlined,        cat:_Cat.finance,  build:() => const DiscountCalc()),
  _ToolDef(id:'emi',      title:'EMI / Loan',          subtitle:'Monthly payment calculator',     icon:Icons.account_balance_outlined,    cat:_Cat.finance,  build:() => const EMICalc()),
  _ToolDef(id:'interest', title:'Interest',            subtitle:'Simple & compound',              icon:Icons.savings_outlined,            cat:_Cat.finance,  build:() => const InterestCalc()),
  _ToolDef(id:'tip',      title:'Tip & Bill Split',    subtitle:'Tip % + split between people',   icon:Icons.restaurant_outlined,         cat:_Cat.finance,  build:() => const TipCalc()),
  _ToolDef(id:'currency', title:'Currency Converter',  subtitle:'30 currencies · offline rates',  icon:Icons.currency_exchange_rounded,   cat:_Cat.finance,  build:() => const CurrencyCalc()),
  _ToolDef(id:'profit',   title:'Profit & Loss',       subtitle:'Cost vs. selling price',         icon:Icons.trending_up_rounded,         cat:_Cat.finance,  build:() => const ProfitLossCalc()),
  _ToolDef(id:'unit',     title:'Unit Converter',      subtitle:'Length/Weight/Temp/Volume +8',   icon:Icons.swap_horiz_rounded,          cat:_Cat.unit,     build:() => const UnitConverter()),
  _ToolDef(id:'bmi',      title:'BMI',                 subtitle:'Body Mass Index (kg/cm, lb/ft)', icon:Icons.monitor_weight_outlined,     cat:_Cat.health,   build:() => const BMICalc()),
  _ToolDef(id:'bmr',      title:'BMR / Calories',      subtitle:'Daily calorie needs (TDEE)',     icon:Icons.local_fire_department_outlined, cat:_Cat.health, build:() => const BMRCalc()),
  _ToolDef(id:'age',      title:'Age Calculator',      subtitle:'Exact years/months/days',        icon:Icons.cake_outlined,               cat:_Cat.health,   build:() => const AgeCalc()),
  _ToolDef(id:'preg',     title:'Pregnancy Due Date',  subtitle:'Due date + current week',        icon:Icons.child_care_outlined,         cat:_Cat.health,   build:() => const PregnancyCalc()),
  _ToolDef(id:'bp',       title:'Blood Pressure',      subtitle:'Reading category checker',       icon:Icons.favorite_border_rounded,     cat:_Cat.health,   build:() => const BPCalc()),
  _ToolDef(id:'water',    title:'Water Intake',        subtitle:'Daily water by weight & activity',icon:Icons.water_drop_outlined,        cat:_Cat.health,   build:() => const WaterIntakeCalc()),
  _ToolDef(id:'idealwt',  title:'Ideal Weight',        subtitle:'Healthy weight range by height', icon:Icons.accessibility_outlined,      cat:_Cat.health,   build:() => const IdealWeightCalc()),
  _ToolDef(id:'base',     title:'Number Base',         subtitle:'Binary/Octal/Decimal/Hex',       icon:Icons.tag_rounded,                 cat:_Cat.everyday, build:() => const BaseConverter()),
  _ToolDef(id:'roman',    title:'Roman Numerals',      subtitle:'Decimal ↔ Roman numeral',        icon:Icons.history_edu_rounded,         cat:_Cat.everyday, build:() => const RomanConverter()),
  _ToolDef(id:'datediff', title:'Date Difference',     subtitle:'Days/weeks/months between dates', icon:Icons.date_range_outlined,        cat:_Cat.everyday, build:() => const DateDiffCalc()),
  _ToolDef(id:'tz',       title:'Timezone Converter',  subtitle:'20 timezones · offline',         icon:Icons.schedule_rounded,            cat:_Cat.everyday, build:() => const TimezoneCalc()),
  _ToolDef(id:'gpa',      title:'Grade / GPA',         subtitle:'GPA on 10 & 4.0 scale',         icon:Icons.school_outlined,             cat:_Cat.everyday, build:() => const GradeCalc()),
  _ToolDef(id:'frac',     title:'Fraction Simplifier', subtitle:'Reduce + decimal + percent',     icon:Icons.calculate_outlined,          cat:_Cat.everyday, build:() => const FractionCalc()),
  _ToolDef(id:'lcmgcd',   title:'LCM & GCD',           subtitle:'Least common multiple / GCD',    icon:Icons.workspaces_outlined,         cat:_Cat.everyday, build:() => const LcmGcdCalc()),
  _ToolDef(id:'prime',    title:'Prime Checker',       subtitle:'Is it prime? + factors',         icon:Icons.numbers_rounded,             cat:_Cat.everyday, build:() => const PrimeChecker()),
  _ToolDef(id:'rng',      title:'Random Generator',    subtitle:'Numbers, dice, coin flip',       icon:Icons.casino_outlined,             cat:_Cat.everyday, build:() => const RandomGen()),
];

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _search = TextEditingController();
  _Cat? _filter;
  String _query = '';

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  List<_ToolDef> get _visible {
    return _tools.where((t) {
      final matchCat = _filter == null || t.cat == _filter;
      final matchQ   = _query.isEmpty ||
          t.title.toLowerCase().contains(_query) ||
          t.subtitle.toLowerCase().contains(_query);
      return matchCat && matchQ;
    }).toList();
  }

  void _open(BuildContext context, _ToolDef tool) {
    // Button-layout calculators need 95% height; form-based tools only need 85%.
    final isCalc = tool.id == 'basic' || tool.id == 'sci';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GemColors.bg,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ToolSheet(tool: tool, fullHeight: isCalc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

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
                color: GemColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GemColors.accent.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.calculate_rounded, size: 15, color: GemColors.accent),
            ),
            const SizedBox(width: 10),
            const Text('Calculator',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                style: const TextStyle(fontSize: 14, color: Colors.white),
                cursorColor: GemColors.accent,
                onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
                decoration: InputDecoration(
                  hintText: 'Search calculators…',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.3)),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.white.withValues(alpha: 0.35)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          color: Colors.white.withValues(alpha: 0.4),
                          onPressed: () { _search.clear(); setState(() => _query = ''); },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: GemColors.accent, width: 1.2),
                  ),
                ),
              ),
            ),

            // Category chips
            SizedBox(
              height: 38,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip('All', null),
                  ...(_Cat.values.map((c) => _filterChip(_catLabels[c]!, c))),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Tool grid
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text('No tools match "$_query"',
                          style: const TextStyle(color: GemColors.textSecondary, fontSize: 14)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.55,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (ctx, i) => _ToolCard(
                        tool: visible[i],
                        onTap: () => _open(ctx, visible[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _Cat? cat) {
    final sel = _filter == cat;
    final color = cat == null ? GemColors.accent : (_catColors[cat] ?? GemColors.accent);
    return GestureDetector(
      onTap: () => setState(() => _filter = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? color.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
            color: sel ? color : GemColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// TOOL GRID CARD

class _ToolCard extends StatelessWidget {
  final _ToolDef tool;
  final VoidCallback onTap;

  const _ToolCard({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _catColors[tool.cat] ?? GemColors.accent;
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        decoration: BoxDecoration(
          color: GemColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tool.icon, size: 16, color: color),
            ),
            const Spacer(),
            Text(
              tool.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              tool.subtitle,
              style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.45)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// MODAL TOOL SHEET

class _ToolSheet extends StatelessWidget {
  final _ToolDef tool;
  final bool fullHeight;

  const _ToolSheet({required this.tool, required this.fullHeight});

  @override
  Widget build(BuildContext context) {
    final color = _catColors[tool.cat] ?? GemColors.accent;
    final maxH = MediaQuery.of(context).size.height * (fullHeight ? 0.95 : 0.85);

    return SizedBox(
      height: maxH,
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tool.icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tool.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(tool.subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45))),
              ])),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: Colors.white.withValues(alpha: 0.4)),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Divider(height: 1, thickness: 0.5, color: Colors.white.withValues(alpha: 0.07)),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: tool.build(),
            ),
          ),
        ],
      ),
    );
  }
}

// BASIC CALCULATOR WIDGET

class _BasicCalcWidget extends StatefulWidget {
  const _BasicCalcWidget();

  @override
  State<_BasicCalcWidget> createState() => _BasicCalcWidgetState();
}

class _BasicCalcWidgetState extends State<_BasicCalcWidget> {
  final _engine = _CalcEngine();

  void _press(String token) {
    HapticFeedback.lightImpact();
    setState(() => _engine.input(token));
  }

  static const _rows = [
    ['AC', '⌫', '%', '÷'],
    ['7',  '8',  '9',  '×'],
    ['4',  '5',  '6',  '-'],
    ['1',  '2',  '3',  '+'],
    ['±',  '0',  '.',  '='],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Display(engine: _engine),
      const Divider(height: 1, thickness: 0.5, color: GemColors.cardBorder),
      SizedBox(
        height: 340,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Column(
            children: _rows.map((row) {
              return Expanded(
                child: Row(
                  children: row.map((label) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: _CalcButton(
                          label: label,
                          onTap: () => _handleToken(label),
                          style: _styleFor(label),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ]);
  }

  void _handleToken(String t) {
    if (t == '%') {
      final v = double.tryParse(_engine.display) ?? 0;
      setState(() => _engine._display = _engine._formatNum(v / 100));
    } else if (t == '±') {
      final v = double.tryParse(_engine.display) ?? 0;
      setState(() => _engine._display = _engine._formatNum(-v));
    } else {
      _press(t);
    }
  }

  _BtnStyle _styleFor(String t) {
    if (t == '=') return _BtnStyle.primary;
    if (t == 'AC' || t == '⌫') return _BtnStyle.function;
    if (t == '÷' || t == '×' || t == '-' || t == '+' || t == '%') return _BtnStyle.operator;
    return _BtnStyle.digit;
  }
}

// SCIENTIFIC CALCULATOR WIDGET

class _SciCalcWidget extends StatefulWidget {
  const _SciCalcWidget();

  @override
  State<_SciCalcWidget> createState() => _SciCalcWidgetState();
}

class _SciCalcWidgetState extends State<_SciCalcWidget> {
  final _engine = _CalcEngine();
  bool _isDeg = true;

  // Multiplying by 1.0 in RAD mode is a no-op; DEG mode converts before passing to dart:math trig.
  double get _angleToRad => _isDeg ? math.pi / 180 : 1.0;

  void _press(String token) {
    HapticFeedback.lightImpact();
    setState(() => _engine.input(token));
  }

  void _sciFunction(String fn) {
    HapticFeedback.lightImpact();
    final v = double.tryParse(_engine._display);
    if (v == null) return;
    double? result;
    try {
      result = switch (fn) {
        'sin'   => math.sin(v * _angleToRad),
        'cos'   => math.cos(v * _angleToRad),
        'tan'   => math.tan(v * _angleToRad),
        'sin⁻¹' => v >= -1 && v <= 1 ? math.asin(v) / _angleToRad : null,
        'cos⁻¹' => v >= -1 && v <= 1 ? math.acos(v) / _angleToRad : null,
        'tan⁻¹' => math.atan(v) / _angleToRad,
        'log'   => math.log(v) / math.ln10,
        'ln'    => math.log(v),
        'x²'    => v * v,
        'x³'    => v * v * v,
        '√'     => math.sqrt(v),
        '∛'     => math.pow(v, 1 / 3).toDouble(),
        '1/x'   => 1 / v,
        'eˣ'    => math.exp(v),
        '10ˣ'   => math.pow(10, v).toDouble(),
        'π'     => math.pi,
        'e'     => math.e,
        '%'     => v / 100,
        '±'     => -v,
        _       => null,
      };
    } catch (_) {
      result = null;
    }
    if (result == null) return;
    setState(() {
      _engine._display    = _engine._formatNum(result!);
      _engine._result     = _engine._display;
      _engine._expression = '$fn($v) =';
      _engine._justEvaled = true;
    });
  }

  static const _sciRows = [
    ['sin',  'cos',   'tan',  '÷'],
    ['sin⁻¹','cos⁻¹','tan⁻¹','×'],
    ['log',  'ln',    'eˣ',   '-'],
    ['x²',   'x³',   '√',    '+'],
    ['π',    'e',    '1/x',  '='],
  ];

  static const _numRows = [
    ['AC', '⌫', '%',  '10ˣ'],
    ['7',  '8',  '9',  '∛'],
    ['4',  '5',  '6',  '±'],
    ['1',  '2',  '3',  '.'],
    ['0',  '00', 'DEG','RAD'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Display(engine: _engine, extra: _isDeg ? 'DEG' : 'RAD'),
      const Divider(height: 1, thickness: 0.5, color: GemColors.cardBorder),
      SizedBox(
        height: 340,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
          child: Row(children: [
            Expanded(
              child: Column(
                children: _sciRows.map((row) {
                  return Expanded(
                    child: Row(
                      children: row.map((label) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2.5),
                            child: _CalcButton(
                              label: label,
                              onTap: () => _handleSci(label),
                              style: _sciStyleFor(label),
                              fontSize: 11.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
            VerticalDivider(width: 1, thickness: 0.5, color: Colors.white.withValues(alpha: 0.07)),
            Expanded(
              child: Column(
                children: _numRows.map((row) {
                  return Expanded(
                    child: Row(
                      children: row.map((label) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2.5),
                            child: _CalcButton(
                              label: label,
                              onTap: () => _handleNum(label),
                              style: _numStyleFor(label),
                              fontSize: 12.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  void _handleSci(String t) {
    if (t == '÷' || t == '×' || t == '-' || t == '+' || t == '=') {
      _press(t);
    } else {
      _sciFunction(t);
    }
  }

  void _handleNum(String t) {
    if (t == 'DEG') { setState(() => _isDeg = true); }
    else if (t == 'RAD') { setState(() => _isDeg = false); }
    else if (t == '00') { if (_engine._display != '0') { _press('0'); _press('0'); } }
    else if (t == '±' || t == '%' || t == '10ˣ' || t == '∛') { _sciFunction(t); }
    else { _press(t); }
  }

  _BtnStyle _sciStyleFor(String t) {
    if (t == '=') return _BtnStyle.primary;
    if (t == '÷' || t == '×' || t == '-' || t == '+') return _BtnStyle.operator;
    return _BtnStyle.science;
  }

  _BtnStyle _numStyleFor(String t) {
    if (t == 'AC' || t == '⌫') return _BtnStyle.function;
    if (t == '%' || t == '10ˣ' || t == '∛' || t == '±') return _BtnStyle.operator;
    if (t == 'DEG' || t == 'RAD') {
      return _isDeg == (t == 'DEG') ? _BtnStyle.primary : _BtnStyle.function;
    }
    return _BtnStyle.digit;
  }
}

// _CalcEngine handles button-by-button input state; Calculator (lib/core/calculator.dart)
// evaluates complete expression strings. They serve different use cases.
class _CalcEngine {
  String _expression = '';
  String _display    = '0';
  String _result     = '';
  bool   _justEvaled = false;

  String get display    => _display;
  String get expression => _expression;

  void input(String token) {
    if (token == 'AC') {
      _expression = ''; _display = '0'; _result = ''; _justEvaled = false; return;
    }
    if (token == '⌫') {
      _display = _display.length > 1 ? _display.substring(0, _display.length - 1) : '0';
      _justEvaled = false; return;
    }
    if (token == '=') { _evaluate(); return; }
    final isOp = _isOperator(token);
    // After evaluation, a digit starts a fresh entry rather than appending to the result.
    if (_justEvaled && !isOp) {
      _expression = ''; _display = ''; _result = ''; _justEvaled = false;
    }
    if (isOp) {
      final val = _result.isNotEmpty ? _result : _display;
      _expression = '$val $token ';
      _display    = _expression;
      _result     = '';
      _justEvaled = false;
      return;
    }
    if (token == '.') {
      if (_display.contains('.')) return;
      _display = _display.isEmpty ? '0.' : '$_display.';
      return;
    }
    _display = _display == '0' ? token : '$_display$token';
  }

  void _evaluate() {
    try {
      final expr = _expression.isEmpty ? _display : '$_expression$_display';
      final val = _evalExpr(expr.trim());
      _result     = _formatNum(val);
      _expression = '$expr =';
      _display    = _result;
      _justEvaled = true;
    } catch (_) {
      _display = 'Error'; _expression = ''; _result = ''; _justEvaled = false;
    }
  }

  double _evalExpr(String expr) {
    final tokens = expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .split(RegExp(r'(?<=[0-9.])(?=[+\-*/])|(?<=[+\-*/])(?=[0-9.])'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final nums = <double>[];
    final ops  = <String>[];
    for (final t in tokens) {
      if (t == '+' || t == '-' || t == '*' || t == '/') { ops.add(t); }
      else { nums.add(double.parse(t)); }
    }
    int i = 0;
    while (i < ops.length) {
      if (ops[i] == '*' || ops[i] == '/') {
        final res = ops[i] == '*' ? nums[i] * nums[i+1] : nums[i] / nums[i+1];
        nums.replaceRange(i, i+2, [res]); ops.removeAt(i);
      } else { i++; }
    }
    double result = nums[0];
    for (int j = 0; j < ops.length; j++) {
      result += ops[j] == '+' ? nums[j+1] : -nums[j+1];
    }
    return result;
  }

  String _formatNum(double v) {
    if (v.isNaN || v.isInfinite) return 'Error';
    if (v == v.truncateToDouble() && v.abs() < 1e12) return v.toInt().toString();
    return v.toStringAsPrecision(10).replaceAll(RegExp(r'\.?0+$'), '');
  }

  bool _isOperator(String t) => t == '+' || t == '-' || t == '×' || t == '÷';
}

// DISPLAY

class _Display extends StatelessWidget {
  final _CalcEngine engine;
  final String? extra;

  const _Display({required this.engine, this.extra});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (extra != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: GemColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GemColors.accent.withValues(alpha: 0.35)),
                ),
                child: Text(extra!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: GemColors.accent, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (engine.expression.isNotEmpty)
            Text(engine.expression, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.38)), textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              engine.display,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: engine.display == 'Error' ? GemColors.danger : Colors.white,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// BUTTON

enum _BtnStyle { digit, operator, function, primary, science }

class _CalcButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final _BtnStyle style;
  final double fontSize;

  const _CalcButton({
    required this.label,
    required this.onTap,
    required this.style,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final (bg, fg, border) = switch (style) {
      _BtnStyle.primary  => (accent.withValues(alpha: 0.85), Colors.white, Colors.transparent),
      _BtnStyle.operator => (accent.withValues(alpha: 0.12), accent, accent.withValues(alpha: 0.3)),
      _BtnStyle.function => (Colors.white.withValues(alpha: 0.07), GemColors.textSecondary, Colors.white.withValues(alpha: 0.1)),
      _BtnStyle.science  => (Colors.white.withValues(alpha: 0.04), Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0.08)),
      _BtnStyle.digit    => (Colors.white.withValues(alpha: 0.06), Colors.white, Colors.white.withValues(alpha: 0.1)),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: accent.withValues(alpha: 0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 0.8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: style == _BtnStyle.primary ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
