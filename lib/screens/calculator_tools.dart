import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

Widget calcField(
  String label,
  TextEditingController ctrl, {
  String? hint,
  TextInputType type = const TextInputType.numberWithOptions(decimal: true, signed: true),
  void Function(String)? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: GemColors.textSecondary)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(fontSize: 15, color: Colors.white),
        cursorColor: GemColors.accent,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.25)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: GemColors.accent, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

Widget calcDropdown<T>(
  String label,
  T value,
  List<({T v, String label})> items,
  void Function(T?) onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: GemColors.textSecondary)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            dropdownColor: GemColors.surface,
            isExpanded: true,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            items: items
                .map((e) => DropdownMenuItem(value: e.v, child: Text(e.label)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

Widget calcBtn(String label, VoidCallback onTap, Color accent) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () { HapticFeedback.lightImpact(); onTap(); },
      style: ElevatedButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.2),
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    ),
  );
}

Widget resultBox(String? result, Color accent) {
  if (result == null) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.3)),
    ),
    child: Text(
      result,
      style: TextStyle(fontSize: 15, color: accent, height: 1.6),
    ),
  );
}

String _fmt(double v, {int decimals = 2}) {
  if (v.isNaN || v.isInfinite) return 'Error';
  if (v == v.truncateToDouble() && v.abs() < 1e12) return v.toInt().toString();
  return v.toStringAsFixed(decimals).replaceAll(RegExp(r'\.?0+$'), '');
}



class PercentageCalc extends StatefulWidget {
  const PercentageCalc({super.key});
  @override State<PercentageCalc> createState() => _PercentageCalcState();
}
class _PercentageCalcState extends State<PercentageCalc> {
  final _x  = TextEditingController();
  final _y  = TextEditingController();
  String? _r;

  @override void dispose() { _x.dispose(); _y.dispose(); super.dispose(); }

  void _calc(String mode) {
    final x = double.tryParse(_x.text);
    final y = double.tryParse(_y.text);
    if (x == null || y == null) return;
    setState(() {
      _r = switch (mode) {
        'of'     => '${_fmt(x)}% of ${_fmt(y)} = ${_fmt(x / 100 * y)}',
        'inc'    => '${_fmt(y)} increased by ${_fmt(x)}% = ${_fmt(y * (1 + x / 100))}',
        'dec'    => '${_fmt(y)} decreased by ${_fmt(x)}% = ${_fmt(y * (1 - x / 100))}',
        'diff'   => 'Change from ${_fmt(x)} to ${_fmt(y)} = ${_fmt((y - x) / x * 100)}%',
        _        => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      calcField('Percentage (%)', _x, hint: 'e.g. 15'),
      const SizedBox(height: 12),
      calcField('Value', _y, hint: 'e.g. 200'),
      const SizedBox(height: 16),
      Row(children: [
        for (final (label, mode) in [
          ('X% of Y', 'of'), ('Increase', 'inc'), ('Decrease', 'dec'), ('Diff %', 'diff'),
        ]) ...[
          Expanded(child: ElevatedButton(
            onPressed: () => _calc(mode),
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.studyColor.withValues(alpha: 0.12),
              foregroundColor: GemColors.studyColor,
              side: BorderSide(color: GemColors.studyColor.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 6),
        ],
      ]),
      resultBox(_r, GemColors.studyColor),
    ]);
  }
}

class DiscountCalc extends StatefulWidget {
  const DiscountCalc({super.key});
  @override State<DiscountCalc> createState() => _DiscountCalcState();
}
class _DiscountCalcState extends State<DiscountCalc> {
  final _price    = TextEditingController();
  final _discount = TextEditingController();
  String? _r;

  @override void dispose() { _price.dispose(); _discount.dispose(); super.dispose(); }

  void _calc() {
    final p = double.tryParse(_price.text);
    final d = double.tryParse(_discount.text);
    if (p == null || d == null) return;
    final savings = p * d / 100;
    final final_ = p - savings;
    setState(() => _r = 'Final price: ${_fmt(final_)}\nYou save: ${_fmt(savings)} (${_fmt(d)}% off)');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Original Price', _price, hint: 'e.g. 1500'),
    const SizedBox(height: 12),
    calcField('Discount (%)', _discount, hint: 'e.g. 20'),
    const SizedBox(height: 16),
    calcBtn('Calculate Discount', _calc, GemColors.studyColor),
    resultBox(_r, GemColors.studyColor),
  ]);
}

class EMICalc extends StatefulWidget {
  const EMICalc({super.key});
  @override State<EMICalc> createState() => _EMICalcState();
}
class _EMICalcState extends State<EMICalc> {
  final _principal = TextEditingController();
  final _rate      = TextEditingController();
  final _months    = TextEditingController();
  String? _r;

  @override void dispose() { _principal.dispose(); _rate.dispose(); _months.dispose(); super.dispose(); }

  void _calc() {
    final P = double.tryParse(_principal.text);
    final r = double.tryParse(_rate.text);
    final n = int.tryParse(_months.text);
    if (P == null || r == null || n == null || n <= 0) return;
    final monthlyRate = r / 100 / 12;
    final emi = monthlyRate == 0
        ? P / n
        : P * monthlyRate * math.pow(1 + monthlyRate, n) / (math.pow(1 + monthlyRate, n) - 1);
    final total = emi * n;
    final interest = total - P;
    setState(() => _r = 'Monthly EMI: ${_fmt(emi)}\nTotal Payment: ${_fmt(total)}\nTotal Interest: ${_fmt(interest)}');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Loan Amount (Principal)', _principal, hint: 'e.g. 500000'),
    const SizedBox(height: 12),
    calcField('Annual Interest Rate (%)', _rate, hint: 'e.g. 8.5'),
    const SizedBox(height: 12),
    calcField('Loan Period (months)', _months, hint: 'e.g. 60', type: TextInputType.number),
    const SizedBox(height: 16),
    calcBtn('Calculate EMI', _calc, GemColors.accent),
    resultBox(_r, GemColors.accent),
  ]);
}

class InterestCalc extends StatefulWidget {
  const InterestCalc({super.key});
  @override State<InterestCalc> createState() => _InterestCalcState();
}
class _InterestCalcState extends State<InterestCalc> {
  final _p    = TextEditingController();
  final _r    = TextEditingController();
  final _t    = TextEditingController();
  bool _compound = false;
  String? _result;

  @override void dispose() { _p.dispose(); _r.dispose(); _t.dispose(); super.dispose(); }

  void _calc() {
    final P = double.tryParse(_p.text);
    final r = double.tryParse(_r.text);
    final t = double.tryParse(_t.text);
    if (P == null || r == null || t == null) return;
    double interest, amount;
    if (_compound) {
      amount   = P * math.pow(1 + r / 100, t);
      interest = amount - P;
    } else {
      interest = P * r * t / 100;
      amount   = P + interest;
    }
    setState(() => _result = 'Interest: ${_fmt(interest)}\nTotal Amount: ${_fmt(amount)}');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Principal', _p, hint: 'e.g. 10000'),
    const SizedBox(height: 12),
    calcField('Annual Rate (%)', _r, hint: 'e.g. 7.5'),
    const SizedBox(height: 12),
    calcField('Time (years)', _t, hint: 'e.g. 3'),
    const SizedBox(height: 12),
    Row(children: [
      const Text('Type:', style: TextStyle(fontSize: 13, color: GemColors.textSecondary)),
      const SizedBox(width: 16),
      _typeChip('Simple', !_compound, () => setState(() => _compound = false)),
      const SizedBox(width: 8),
      _typeChip('Compound', _compound, () => setState(() => _compound = true)),
    ]),
    const SizedBox(height: 16),
    calcBtn('Calculate', _calc, GemColors.iceBlue),
    resultBox(_result, GemColors.iceBlue),
  ]);

  Widget _typeChip(String l, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? GemColors.iceBlue.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? GemColors.iceBlue.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(l, style: TextStyle(fontSize: 13, color: sel ? GemColors.iceBlue : GemColors.textSecondary)),
      ),
    );
  }
}

class TipCalc extends StatefulWidget {
  const TipCalc({super.key});
  @override State<TipCalc> createState() => _TipCalcState();
}
class _TipCalcState extends State<TipCalc> {
  final _bill    = TextEditingController();
  final _tip     = TextEditingController(text: '15');
  final _people  = TextEditingController(text: '1');
  String? _r;

  @override void dispose() { _bill.dispose(); _tip.dispose(); _people.dispose(); super.dispose(); }

  void _calc() {
    final bill   = double.tryParse(_bill.text);
    final tip    = double.tryParse(_tip.text);
    final people = int.tryParse(_people.text);
    if (bill == null || tip == null || people == null || people < 1) return;
    final tipAmt  = bill * tip / 100;
    final total   = bill + tipAmt;
    final perHead = total / people;
    setState(() => _r = 'Tip amount: ${_fmt(tipAmt)}\nTotal bill: ${_fmt(total)}\nPer person: ${_fmt(perHead)}');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Bill Amount', _bill, hint: 'e.g. 1200'),
    const SizedBox(height: 12),
    calcField('Tip (%)', _tip, hint: '15'),
    const SizedBox(height: 12),
    calcField('Split between (people)', _people, hint: '1', type: TextInputType.number),
    const SizedBox(height: 16),
    calcBtn('Calculate', _calc, GemColors.warning),
    resultBox(_r, GemColors.warning),
  ]);
}

class CurrencyCalc extends StatefulWidget {
  const CurrencyCalc({super.key});
  @override State<CurrencyCalc> createState() => _CurrencyCalcState();
}
class _CurrencyCalcState extends State<CurrencyCalc> {
  // Hardcoded offline rates (USD base); result includes a freshness disclosure label.
  static const Map<String, double> _rates = {
    'USD': 1.0, 'EUR': 0.91, 'GBP': 0.78, 'INR': 83.12, 'JPY': 149.50,
    'CNY': 7.24, 'AUD': 1.53, 'CAD': 1.36, 'CHF': 0.88, 'SGD': 1.34,
    'AED': 3.67, 'SAR': 3.75, 'MYR': 4.73, 'THB': 35.20, 'IDR': 15600.0,
    'PKR': 278.0, 'BDT': 110.0, 'LKR': 320.0, 'NPR': 133.0, 'ZAR': 18.60,
    'NGN': 1510.0, 'KES': 130.0, 'GHS': 12.10, 'BRL': 4.97, 'MXN': 17.15,
    'TRY': 30.80, 'RUB': 89.50, 'KRW': 1325.0, 'HKD': 7.82, 'PHP': 56.20,
  };

  final _amount = TextEditingController(text: '1');
  String _from = 'USD';
  String _to   = 'INR';
  String? _r;

  @override void dispose() { _amount.dispose(); super.dispose(); }

  void _calc() {
    final a = double.tryParse(_amount.text);
    if (a == null) return;
    final usd    = a / _rates[_from]!;
    final result = usd * _rates[_to]!;
    setState(() => _r = '${_fmt(a, decimals: 4)} $_from = ${_fmt(result, decimals: 4)} $_to\n(Offline rates · May 2025)');
  }

  List<({String v, String label})> get _items =>
      _rates.keys.map((k) => (v: k, label: k)).toList();

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Amount', _amount, hint: '1', onChanged: (_) => _calc()),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: calcDropdown('From', _from, _items, (v) { if (v != null) { setState(() => _from = v); _calc(); }})),
      Padding(
        padding: const EdgeInsets.only(top: 22, left: 8, right: 8),
        child: GestureDetector(
          onTap: () { setState(() { final t = _from; _from = _to; _to = t; }); _calc(); },
          child: const Icon(Icons.swap_horiz_rounded, color: GemColors.iceBlue, size: 24),
        ),
      ),
      Expanded(child: calcDropdown('To', _to, _items, (v) { if (v != null) { setState(() => _to = v); _calc(); }})),
    ]),
    const SizedBox(height: 16),
    calcBtn('Convert', _calc, GemColors.iceBlue),
    resultBox(_r, GemColors.iceBlue),
  ]);
}

class ProfitLossCalc extends StatefulWidget {
  const ProfitLossCalc({super.key});
  @override State<ProfitLossCalc> createState() => _ProfitLossCalcState();
}
class _ProfitLossCalcState extends State<ProfitLossCalc> {
  final _cost   = TextEditingController();
  final _sell   = TextEditingController();
  String? _r;

  @override void dispose() { _cost.dispose(); _sell.dispose(); super.dispose(); }

  void _calc() {
    final c = double.tryParse(_cost.text);
    final s = double.tryParse(_sell.text);
    if (c == null || s == null || c == 0) return;
    final diff = s - c;
    final pct  = diff / c * 100;
    final label = diff >= 0 ? 'Profit' : 'Loss';
    setState(() => _r = '$label: ${_fmt(diff.abs())}\n$label %: ${_fmt(pct.abs())}%');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Cost Price', _cost, hint: 'e.g. 800'),
    const SizedBox(height: 12),
    calcField('Selling Price', _sell, hint: 'e.g. 1000'),
    const SizedBox(height: 16),
    calcBtn('Calculate', _calc, GemColors.success),
    resultBox(_r, GemColors.success),
  ]);
}



class UnitConverter extends StatefulWidget {
  const UnitConverter({super.key});
  @override State<UnitConverter> createState() => _UnitConverterState();
}

class _UnitConverterState extends State<UnitConverter> {
  String _cat = 'Length';
  final _val = TextEditingController(text: '1');
  String? _fromUnit;
  String? _toUnit;
  String? _r;

  static const _cats = [
    'Length','Weight','Temperature','Area','Volume','Speed','Data','Time','Pressure','Energy','Fuel',
  ];

  static const Map<String, Map<String, double>> _tables = {
    'Length':      {'mm':0.001,'cm':0.01,'m':1.0,'km':1000.0,'inch':0.0254,'ft':0.3048,'yd':0.9144,'mile':1609.34},
    'Weight':      {'mg':0.001,'g':1.0,'kg':1000.0,'ton':1e6,'oz':28.3495,'lb':453.592},
    'Area':        {'mm²':1e-6,'cm²':0.0001,'m²':1.0,'km²':1e6,'hectare':10000.0,'acre':4046.86,'ft²':0.0929,'in²':0.000645},
    'Volume':      {'ml':0.001,'L':1.0,'fl oz':0.02957,'cup':0.2366,'pint':0.4732,'quart':0.9464,'gallon':3.7854,'m³':1000.0},
    'Speed':       {'m/s':1.0,'km/h':0.27778,'mph':0.44704,'knot':0.51444,'ft/s':0.3048},
    'Data':        {'bit':0.125,'byte':1.0,'KB':1024.0,'MB':1048576.0,'GB':1073741824.0,'TB':1.0995e12},
    'Time':        {'ms':0.001,'s':1.0,'min':60.0,'hr':3600.0,'day':86400.0,'week':604800.0,'month':2628000.0,'year':31536000.0},
    'Pressure':    {'Pa':1.0,'kPa':1000.0,'bar':100000.0,'psi':6894.76,'atm':101325.0,'mmHg':133.322},
    'Energy':      {'J':1.0,'kJ':1000.0,'cal':4.184,'kcal':4184.0,'Wh':3600.0,'kWh':3600000.0,'BTU':1055.06},
    'Fuel':        {'km/L':1.0,'mpg':2.35215,'L/100km':0.0}, // special
  };

  List<String> get _units {
    if (_cat == 'Temperature') return ['°C','°F','K'];
    return _tables[_cat]?.keys.toList() ?? [];
  }

  void _ensureUnits() {
    final u = _units;
    if (!u.contains(_fromUnit)) _fromUnit = u.first;
    if (!u.contains(_toUnit)) _toUnit = u.length > 1 ? u[1] : u.first;
  }

  void _calc() {
    _ensureUnits();
    final v = double.tryParse(_val.text);
    if (v == null) return;
    final result = _convert(v, _fromUnit!, _toUnit!);
    if (result == null) { setState(() => _r = 'Conversion error'); return; }
    setState(() => _r = '${_fmt(v, decimals: 6)} $_fromUnit = ${_fmt(result, decimals: 6)} $_toUnit');
  }

  double? _convert(double v, String from, String to) {
    if (from == to) return v;
    // Temperature and fuel are special-cased: temperature has a non-zero offset,
    // and L/100km is an inverse relationship (larger = worse), not a linear multiplier.
    if (_cat == 'Temperature') return _convertTemp(v, from, to);
    if (_cat == 'Fuel') return _convertFuel(v, from, to);
    final table = _tables[_cat];
    if (table == null) return null;
    final base = v * (table[from] ?? 1.0);
    return base / (table[to] ?? 1.0);
  }

  double _convertTemp(double v, String from, String to) {
    final celsius = switch (from) {
      '°F' => (v - 32) * 5 / 9,
      'K'  => v - 273.15,
      _    => v,
    };
    return switch (to) {
      '°F' => celsius * 9 / 5 + 32,
      'K'  => celsius + 273.15,
      _    => celsius,
    };
  }

  double _convertFuel(double v, String from, String to) {
    final kml = switch (from) {
      'mpg'    => v / 2.35215,
      'L/100km'=> v == 0 ? double.infinity : 100 / v,
      _        => v,
    };
    return switch (to) {
      'mpg'    => kml * 2.35215,
      'L/100km'=> kml == 0 ? double.infinity : 100 / kml,
      _        => kml,
    };
  }

  @override
  Widget build(BuildContext context) {
    _ensureUnits();
    final units = _units;

    return Column(children: [
      // Category selector
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _cats.map((c) {
            final sel = _cat == c;
            return GestureDetector(
              onTap: () { setState(() { _cat = c; _fromUnit = null; _toUnit = null; _r = null; }); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? GemColors.iceBlue.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? GemColors.iceBlue.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(c, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.normal, color: sel ? GemColors.iceBlue : GemColors.textSecondary)),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 14),
      calcField('Value', _val, hint: '1', onChanged: (_) => _calc()),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: calcDropdown('From', _fromUnit!, units.map((u) => (v: u, label: u)).toList(), (v) { if (v != null) { setState(() => _fromUnit = v); _calc(); }})),
        Padding(
          padding: const EdgeInsets.only(top: 22, left: 8, right: 8),
          child: GestureDetector(
            onTap: () { setState(() { final t = _fromUnit; _fromUnit = _toUnit; _toUnit = t; _r = null; }); _calc(); },
            child: const Icon(Icons.swap_horiz_rounded, color: GemColors.iceBlue, size: 24),
          ),
        ),
        Expanded(child: calcDropdown('To', _toUnit!, units.map((u) => (v: u, label: u)).toList(), (v) { if (v != null) { setState(() => _toUnit = v); _calc(); }})),
      ]),
      const SizedBox(height: 16),
      calcBtn('Convert', _calc, GemColors.iceBlue),
      resultBox(_r, GemColors.iceBlue),
    ]);
  }
}



class BMICalc extends StatefulWidget {
  const BMICalc({super.key});
  @override State<BMICalc> createState() => _BMICalcState();
}
class _BMICalcState extends State<BMICalc> {
  final _weight = TextEditingController();
  final _height = TextEditingController();
  bool _metric  = true;
  String? _r;

  @override void dispose() { _weight.dispose(); _height.dispose(); super.dispose(); }

  void _calc() {
    final w = double.tryParse(_weight.text);
    final h = double.tryParse(_height.text);
    if (w == null || h == null || h == 0) return;
    final wKg = _metric ? w : w * 0.453592;
    final hM  = _metric ? h / 100 : h * 0.3048;
    final bmi = wKg / (hM * hM);
    final cat = bmi < 18.5 ? 'Underweight' : bmi < 25 ? 'Normal weight' : bmi < 30 ? 'Overweight' : 'Obese';
    setState(() => _r = 'BMI: ${_fmt(bmi)}\nCategory: $cat');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: _modeChip('Metric (kg/cm)', _metric, () => setState(() => _metric = true))),
      const SizedBox(width: 8),
      Expanded(child: _modeChip('Imperial (lb/ft)', !_metric, () => setState(() => _metric = false))),
    ]),
    const SizedBox(height: 12),
    calcField(_metric ? 'Weight (kg)' : 'Weight (lb)', _weight, hint: _metric ? 'e.g. 70' : 'e.g. 154'),
    const SizedBox(height: 12),
    calcField(_metric ? 'Height (cm)' : 'Height (ft)', _height, hint: _metric ? 'e.g. 175' : 'e.g. 5.9'),
    const SizedBox(height: 16),
    calcBtn('Calculate BMI', _calc, GemColors.medicColor),
    resultBox(_r, GemColors.medicColor),
  ]);

  Widget _modeChip(String l, bool sel, VoidCallback t) => GestureDetector(
    onTap: t,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: sel ? GemColors.medicColor.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sel ? GemColors.medicColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(child: Text(l, style: TextStyle(fontSize: 12, color: sel ? GemColors.medicColor : GemColors.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
    ),
  );
}

class BMRCalc extends StatefulWidget {
  const BMRCalc({super.key});
  @override State<BMRCalc> createState() => _BMRCalcState();
}
class _BMRCalcState extends State<BMRCalc> {
  final _age    = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String _gender   = 'male';
  String _activity = '1.2';
  String? _r;

  static const _activityOptions = [
    (v: '1.2',  label: 'Sedentary'),
    (v: '1.375',label: 'Light (1-3×/wk)'),
    (v: '1.55', label: 'Moderate (3-5×/wk)'),
    (v: '1.725',label: 'Active (6-7×/wk)'),
    (v: '1.9',  label: 'Very Active'),
  ];

  @override void dispose() { _age.dispose(); _weight.dispose(); _height.dispose(); super.dispose(); }

  void _calc() {
    final age = double.tryParse(_age.text);
    final w   = double.tryParse(_weight.text);
    final h   = double.tryParse(_height.text);
    if (age == null || w == null || h == null) return;
    // Mifflin-St Jeor equation (more accurate than Harris-Benedict for modern populations).
    final bmr = _gender == 'male'
        ? 10 * w + 6.25 * h - 5 * age + 5
        : 10 * w + 6.25 * h - 5 * age - 161;
    final tdee = bmr * double.parse(_activity);
    setState(() => _r = 'BMR: ${_fmt(bmr)} kcal/day\nDaily Calories (TDEE): ${_fmt(tdee)} kcal/day');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: _chip('Male', _gender == 'male', () => setState(() => _gender = 'male'))),
      const SizedBox(width: 8),
      Expanded(child: _chip('Female', _gender == 'female', () => setState(() => _gender = 'female'))),
    ]),
    const SizedBox(height: 12),
    calcField('Age (years)', _age, hint: 'e.g. 25', type: TextInputType.number),
    const SizedBox(height: 12),
    calcField('Weight (kg)', _weight, hint: 'e.g. 70'),
    const SizedBox(height: 12),
    calcField('Height (cm)', _height, hint: 'e.g. 175'),
    const SizedBox(height: 12),
    calcDropdown('Activity Level', _activity, _activityOptions, (v) { if (v != null) setState(() => _activity = v); }),
    const SizedBox(height: 16),
    calcBtn('Calculate', _calc, GemColors.medicColor),
    resultBox(_r, GemColors.medicColor),
  ]);

  Widget _chip(String l, bool sel, VoidCallback t) => GestureDetector(
    onTap: t,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: sel ? GemColors.medicColor.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sel ? GemColors.medicColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(child: Text(l, style: TextStyle(fontSize: 13, color: sel ? GemColors.medicColor : GemColors.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
    ),
  );
}

class AgeCalc extends StatefulWidget {
  const AgeCalc({super.key});
  @override State<AgeCalc> createState() => _AgeCalcState();
}
class _AgeCalcState extends State<AgeCalc> {
  DateTime? _dob;
  String? _r;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: GemColors.accent, surface: GemColors.surface),
        ),
        child: child!,
      ),
    );
    if (d != null) { setState(() { _dob = d; _calc(d); }); }
  }

  void _calc(DateTime dob) {
    final now = DateTime.now();
    int years  = now.year - dob.year;
    int months = now.month - dob.month;
    int days   = now.day - dob.day;
    if (days < 0) { months--; days += DateTime(now.year, now.month, 0).day; }
    if (months < 0) { years--; months += 12; }
    final totalDays = now.difference(dob).inDays;
    setState(() => _r = '$years years, $months months, $days days\n(${totalDays.toString()} days total)');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 18, color: GemColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            _dob == null ? 'Select date of birth' : 'DOB: ${_dob!.day}/${_dob!.month}/${_dob!.year}',
            style: TextStyle(
              fontSize: 14,
              color: _dob == null ? Colors.white.withValues(alpha: 0.3) : Colors.white,
            ),
          ),
        ]),
      ),
    ),
    resultBox(_r, GemColors.medicColor),
  ]);
}

class PregnancyCalc extends StatefulWidget {
  const PregnancyCalc({super.key});
  @override State<PregnancyCalc> createState() => _PregnancyCalcState();
}
class _PregnancyCalcState extends State<PregnancyCalc> {
  DateTime? _lmp;
  String? _r;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 60)),
      firstDate: now.subtract(const Duration(days: 280)),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: GemColors.medicColor, surface: GemColors.surface)),
        child: child!,
      ),
    );
    if (d != null) {
      final due = d.add(const Duration(days: 280));
      final weeks = now.difference(d).inDays ~/ 7;
      setState(() {
        _lmp = d;
        _r = 'Estimated Due Date: ${due.day}/${due.month}/${due.year}\nCurrent Week: Week $weeks of 40';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    const Text('LMP = Last Menstrual Period', style: TextStyle(fontSize: 12, color: GemColors.textSecondary)),
    const SizedBox(height: 10),
    GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_month_outlined, size: 18, color: GemColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            _lmp == null ? 'Select first day of last period' : 'LMP: ${_lmp!.day}/${_lmp!.month}/${_lmp!.year}',
            style: TextStyle(fontSize: 14, color: _lmp == null ? Colors.white.withValues(alpha: 0.3) : Colors.white),
          ),
        ]),
      ),
    ),
    resultBox(_r, GemColors.medicColor),
    if (_r != null)
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('This is an estimate only. Consult a doctor for medical advice.',
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
          textAlign: TextAlign.center),
      ),
  ]);
}

class BPCalc extends StatefulWidget {
  const BPCalc({super.key});
  @override State<BPCalc> createState() => _BPCalcState();
}
class _BPCalcState extends State<BPCalc> {
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  String? _r;

  @override void dispose() { _sys.dispose(); _dia.dispose(); super.dispose(); }

  void _calc() {
    final s = int.tryParse(_sys.text);
    final d = int.tryParse(_dia.text);
    if (s == null || d == null) return;
    final String cat;
    if (s < 120 && d < 80)       { cat = 'Normal'; }
    else if (s < 130 && d < 80)  { cat = 'Elevated'; }
    else if (s < 140 || d < 90)  { cat = 'High · Stage 1'; }
    else if (s < 180 || d < 120) { cat = 'High · Stage 2'; }
    else                          { cat = '⚠ Hypertensive Crisis - seek emergency care immediately'; }
    setState(() => _r = '$s/$d mmHg\nCategory: $cat');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: calcField('Systolic (upper)', _sys, hint: 'e.g. 120', type: TextInputType.number)),
      const SizedBox(width: 12),
      Expanded(child: calcField('Diastolic (lower)', _dia, hint: 'e.g. 80', type: TextInputType.number)),
    ]),
    const SizedBox(height: 16),
    calcBtn('Check', _calc, GemColors.medicColor),
    resultBox(_r, GemColors.medicColor),
  ]);
}

class WaterIntakeCalc extends StatefulWidget {
  const WaterIntakeCalc({super.key});
  @override State<WaterIntakeCalc> createState() => _WaterIntakeCalcState();
}
class _WaterIntakeCalcState extends State<WaterIntakeCalc> {
  final _weight = TextEditingController();
  String _activity = 'low';
  String? _r;

  @override void dispose() { _weight.dispose(); super.dispose(); }

  void _calc() {
    final w = double.tryParse(_weight.text);
    if (w == null) return;
    double base = w * 35; // WHO baseline: 35 ml per kg body weight
    if (_activity == 'moderate') base += 500;
    if (_activity == 'high') base += 1000;
    final cups = base / 237;
    setState(() => _r = '${_fmt(base)} ml / day\n≈ ${_fmt(cups, decimals: 1)} cups (8 fl oz each)');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Body Weight (kg)', _weight, hint: 'e.g. 70'),
    const SizedBox(height: 12),
    const Text('Activity Level', style: TextStyle(fontSize: 12, color: GemColors.textSecondary)),
    const SizedBox(height: 8),
    Row(children: [
      for (final (v, l) in [('low','Low'),('moderate','Moderate'),('high','High')]) ...[
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _activity = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _activity == v ? GemColors.iceBlue.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _activity == v ? GemColors.iceBlue.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(child: Text(l, style: TextStyle(fontSize: 13, color: _activity == v ? GemColors.iceBlue : GemColors.textSecondary))),
          ),
        )),
        if (v != 'high') const SizedBox(width: 8),
      ],
    ]),
    const SizedBox(height: 16),
    calcBtn('Calculate', _calc, GemColors.iceBlue),
    resultBox(_r, GemColors.iceBlue),
  ]);
}

class IdealWeightCalc extends StatefulWidget {
  const IdealWeightCalc({super.key});
  @override State<IdealWeightCalc> createState() => _IdealWeightCalcState();
}
class _IdealWeightCalcState extends State<IdealWeightCalc> {
  final _height = TextEditingController();
  String _gender = 'male';
  String? _r;

  @override void dispose() { _height.dispose(); super.dispose(); }

  void _calc() {
    final h = double.tryParse(_height.text);
    if (h == null) return;
    final inches = h / 2.54;
    // Robinson formula (1983) - widely used clinical baseline.
    final ideal = _gender == 'male'
        ? 52 + 1.9 * (inches - 60)
        : 49 + 1.7 * (inches - 60);
    final low = ideal * 0.9, high = ideal * 1.1;
    setState(() => _r = 'Ideal weight: ${_fmt(ideal)} kg\nHealthy range: ${_fmt(low)}-${_fmt(high)} kg');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: _chip('Male', _gender == 'male', () => setState(() => _gender = 'male'))),
      const SizedBox(width: 8),
      Expanded(child: _chip('Female', _gender == 'female', () => setState(() => _gender = 'female'))),
    ]),
    const SizedBox(height: 12),
    calcField('Height (cm)', _height, hint: 'e.g. 170'),
    const SizedBox(height: 16),
    calcBtn('Calculate', _calc, GemColors.medicColor),
    resultBox(_r, GemColors.medicColor),
  ]);

  Widget _chip(String l, bool sel, VoidCallback t) => GestureDetector(
    onTap: t,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: sel ? GemColors.medicColor.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sel ? GemColors.medicColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(child: Text(l, style: TextStyle(fontSize: 13, color: sel ? GemColors.medicColor : GemColors.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
    ),
  );
}



class BaseConverter extends StatefulWidget {
  const BaseConverter({super.key});
  @override State<BaseConverter> createState() => _BaseConverterState();
}
class _BaseConverterState extends State<BaseConverter> {
  final _input = TextEditingController();
  int _from = 10;
  String? _r;

  void _calc() {
    final s = _input.text.trim().toUpperCase();
    if (s.isEmpty) return;
    try {
      final decimal = int.parse(s, radix: _from);
      setState(() => _r =
          'Binary (2):  ${decimal.toRadixString(2)}\n'
          'Octal (8):   ${decimal.toRadixString(8)}\n'
          'Decimal (10): $decimal\n'
          'Hex (16):     ${decimal.toRadixString(16).toUpperCase()}');
    } catch (_) {
      setState(() => _r = 'Invalid input for base $_from');
    }
  }

  @override void dispose() { _input.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Number', _input, hint: 'Enter number', type: TextInputType.text, onChanged: (_) => _calc()),
    const SizedBox(height: 12),
    const Text('Input Base', style: TextStyle(fontSize: 12, color: GemColors.textSecondary)),
    const SizedBox(height: 8),
    Row(children: [
      for (final b in [2, 8, 10, 16]) ...[
        Expanded(child: GestureDetector(
          onTap: () { setState(() { _from = b; _r = null; _input.clear(); }); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _from == b ? GemColors.warning.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _from == b ? GemColors.warning.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(child: Text('Base $b', style: TextStyle(fontSize: 12, color: _from == b ? GemColors.warning : GemColors.textSecondary))),
          ),
        )),
        if (b != 16) const SizedBox(width: 6),
      ],
    ]),
    resultBox(_r, GemColors.warning),
  ]);
}

class RomanConverter extends StatefulWidget {
  const RomanConverter({super.key});
  @override State<RomanConverter> createState() => _RomanConverterState();
}
class _RomanConverterState extends State<RomanConverter> {
  final _dec   = TextEditingController();
  final _roman = TextEditingController();
  String? _r;

  @override void dispose() { _dec.dispose(); _roman.dispose(); super.dispose(); }

  static const _vals = [(1000,'M'),(900,'CM'),(500,'D'),(400,'CD'),(100,'C'),(90,'XC'),(50,'L'),(40,'XL'),(10,'X'),(9,'IX'),(5,'V'),(4,'IV'),(1,'I')];

  String _toRoman(int n) {
    if (n <= 0 || n > 3999) return 'Out of range (1-3999)';
    final buf = StringBuffer();
    for (final (v, s) in _vals) { while (n >= v) { buf.write(s); n -= v; } }
    return buf.toString();
  }

  int _fromRoman(String s) {
    final map = {'I':1,'V':5,'X':10,'L':50,'C':100,'D':500,'M':1000};
    int result = 0, prev = 0;
    // Right-to-left iteration implements the subtraction rule: IV = 5-1, IX = 10-1.
    for (int i = s.length - 1; i >= 0; i--) {
      final v = map[s[i]] ?? 0;
      result += v < prev ? -v : v;
      prev = v;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Decimal (1-3999)', _dec, hint: 'e.g. 2024', type: TextInputType.number),
    const SizedBox(height: 10),
    calcBtn('→ Roman', () { final n = int.tryParse(_dec.text); if (n != null) setState(() => _r = _toRoman(n)); }, GemColors.warning),
    const SizedBox(height: 12),
    calcField('Roman Numeral', _roman, hint: 'e.g. MMXXIV', type: TextInputType.text),
    const SizedBox(height: 10),
    calcBtn('→ Decimal', () { setState(() => _r = _fromRoman(_roman.text.toUpperCase().trim()).toString()); }, GemColors.warning),
    resultBox(_r, GemColors.warning),
  ]);
}

class DateDiffCalc extends StatefulWidget {
  const DateDiffCalc({super.key});
  @override State<DateDiffCalc> createState() => _DateDiffCalcState();
}
class _DateDiffCalcState extends State<DateDiffCalc> {
  DateTime? _d1, _d2;
  String? _r;

  Future<void> _pick(bool isFirst, BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: GemColors.accent, surface: GemColors.surface)), child: child!),
    );
    if (d == null) return;
    setState(() { if (isFirst) { _d1 = d; } else { _d2 = d; } });
    if (_d1 != null && _d2 != null) {
      final diff = _d2!.difference(_d1!).inDays.abs();
      final weeks = diff ~/ 7;
      final months = (_d2!.year - _d1!.year) * 12 + (_d2!.month - _d1!.month);
      final years  = _d2!.year - _d1!.year;
      setState(() => _r = '$diff days\n${_fmt(weeks.toDouble(), decimals: 0)} weeks\n${months.abs()} months\n${years.abs()} years');
    }
  }

  Widget _dateBtn(String label, DateTime? val, bool isFirst, BuildContext ctx) {
    return GestureDetector(
      onTap: () => _pick(isFirst, ctx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: GemColors.textSecondary),
          const SizedBox(width: 8),
          Text(val == null ? label : '${val.day}/${val.month}/${val.year}',
              style: TextStyle(fontSize: 13, color: val == null ? Colors.white.withValues(alpha: 0.3) : Colors.white)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    _dateBtn('Select start date', _d1, true, context),
    const SizedBox(height: 10),
    _dateBtn('Select end date', _d2, false, context),
    resultBox(_r, GemColors.warning),
  ]);
}

class TimezoneCalc extends StatefulWidget {
  const TimezoneCalc({super.key});
  @override State<TimezoneCalc> createState() => _TimezoneCalcState();
}
class _TimezoneCalcState extends State<TimezoneCalc> {
  // Hardcoded offsets avoid any OS timezone API - required for full offline operation.
  static const _zones = <String, ({String name, double offset})>{
    'UTC' : (name:'UTC / GMT',                offset:0),
    'IST' : (name:'India Standard Time',      offset:5.5),
    'PST' : (name:'Pacific Standard Time',    offset:-8),
    'MST' : (name:'Mountain Standard Time',   offset:-7),
    'CST' : (name:'Central Standard Time',    offset:-6),
    'EST' : (name:'Eastern Standard Time',    offset:-5),
    'BRT' : (name:'Brazil (Brasilia)',         offset:-3),
    'GMT' : (name:'Greenwich Mean Time',       offset:0),
    'CET' : (name:'Central European Time',    offset:1),
    'EET' : (name:'Eastern European Time',    offset:2),
    'MSK' : (name:'Moscow Standard Time',     offset:3),
    'GST' : (name:'Gulf Standard Time',       offset:4),
    'PKT' : (name:'Pakistan Standard Time',   offset:5),
    'BST' : (name:'Bangladesh Standard Time', offset:6),
    'ICT' : (name:'Indochina Time',           offset:7),
    'CST8': (name:'China Standard Time',      offset:8),
    'SGT' : (name:'Singapore Time',           offset:8),
    'JST' : (name:'Japan Standard Time',      offset:9),
    'AEST': (name:'Australian Eastern',       offset:10),
    'NZST': (name:'New Zealand Standard',     offset:12),
  };

  String _from = 'IST';
  String _to   = 'UTC';
  final _hour  = TextEditingController(text: '12');
  final _min   = TextEditingController(text: '00');
  String? _r;

  @override void dispose() { _hour.dispose(); _min.dispose(); super.dispose(); }

  void _calc() {
    final h = int.tryParse(_hour.text);
    final m = int.tryParse(_min.text);
    if (h == null || m == null) return;
    final fromOff = _zones[_from]!.offset;
    final toOff   = _zones[_to]!.offset;
    final totalMin = h * 60 + m - (fromOff * 60).round() + (toOff * 60).round();
    final adjMin   = ((totalMin % 1440) + 1440) % 1440;
    final rH = adjMin ~/ 60, rM = adjMin % 60;
    setState(() => _r = '${_fmt(h.toDouble(), decimals: 0).padLeft(2,'0')}:${_fmt(m.toDouble(), decimals: 0).padLeft(2,'0')} $_from = ${rH.toString().padLeft(2,'0')}:${rM.toString().padLeft(2,'0')} $_to');
  }

  List<({String v, String label})> get _items =>
      _zones.entries.map((e) => (v: e.key, label: '${e.key} - ${e.value.name}')).toList();

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: calcField('Hour (0-23)', _hour, hint: '12', type: TextInputType.number)),
      const SizedBox(width: 12),
      Expanded(child: calcField('Minute (0-59)', _min, hint: '00', type: TextInputType.number)),
    ]),
    const SizedBox(height: 12),
    calcDropdown('From Timezone', _from, _items, (v) { if (v != null) setState(() => _from = v); }),
    const SizedBox(height: 10),
    calcDropdown('To Timezone', _to, _items, (v) { if (v != null) setState(() => _to = v); }),
    const SizedBox(height: 16),
    calcBtn('Convert', _calc, GemColors.warning),
    resultBox(_r, GemColors.warning),
  ]);
}

class GradeCalc extends StatefulWidget {
  const GradeCalc({super.key});
  @override State<GradeCalc> createState() => _GradeCalcState();
}
class _GradeCalcState extends State<GradeCalc> {
  final _subjects = <({TextEditingController grade, TextEditingController credit})>[];
  String? _r;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 5; i++) {
      _subjects.add((grade: TextEditingController(), credit: TextEditingController(text: '3')));
    }
  }

  @override
  void dispose() {
    for (final s in _subjects) { s.grade.dispose(); s.credit.dispose(); }
    super.dispose();
  }

  void _calc() {
    double totalPoints = 0, totalCredits = 0;
    for (final s in _subjects) {
      final g = double.tryParse(s.grade.text);
      final c = double.tryParse(s.credit.text);
      if (g != null && c != null && c > 0) {
        totalPoints  += g * c;
        totalCredits += c;
      }
    }
    if (totalCredits == 0) return;
    final gpa = totalPoints / totalCredits;
    setState(() => _r = 'GPA: ${_fmt(gpa)} / 10\n4.0 Scale: ${_fmt(gpa / 10 * 4)}\nPercentage ≈ ${_fmt(gpa * 9.5)}%');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: const [
      Expanded(flex: 3, child: Text('Grade (0-10)', style: TextStyle(fontSize: 12, color: GemColors.textSecondary))),
      SizedBox(width: 12),
      Expanded(flex: 2, child: Text('Credits', style: TextStyle(fontSize: 12, color: GemColors.textSecondary))),
    ]),
    const SizedBox(height: 6),
    for (int i = 0; i < _subjects.length; i++) ...[
      Row(children: [
        Expanded(flex: 3, child: TextField(
          controller: _subjects[i].grade,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14, color: Colors.white),
          cursorColor: GemColors.accent,
          decoration: InputDecoration(
            hintText: 'S${i+1} grade',
            hintStyle: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true, fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GemColors.accent)),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: TextField(
          controller: _subjects[i].credit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14, color: Colors.white),
          cursorColor: GemColors.accent,
          decoration: InputDecoration(
            hintText: 'Credits',
            hintStyle: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true, fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GemColors.accent)),
          ),
        )),
      ]),
      const SizedBox(height: 8),
    ],
    calcBtn('Calculate GPA', _calc, GemColors.warning),
    resultBox(_r, GemColors.warning),
  ]);
}

class FractionCalc extends StatefulWidget {
  const FractionCalc({super.key});
  @override State<FractionCalc> createState() => _FractionCalcState();
}
class _FractionCalcState extends State<FractionCalc> {
  final _num = TextEditingController();
  final _den = TextEditingController();
  String? _r;

  @override void dispose() { _num.dispose(); _den.dispose(); super.dispose(); }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  void _calc() {
    final n = int.tryParse(_num.text);
    final d = int.tryParse(_den.text);
    if (n == null || d == null || d == 0) return;
    final g = _gcd(n.abs(), d.abs());
    final sn = n ~/ g, sd = d ~/ g;
    final decimal = n / d;
    setState(() => _r = 'Simplified: $sn/$sd\nDecimal: ${_fmt(decimal, decimals: 6)}\nPercent: ${_fmt(decimal * 100)}%');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: calcField('Numerator', _num, hint: 'e.g. 4', type: TextInputType.number)),
      const Padding(padding: EdgeInsets.only(top: 20, left: 14, right: 14), child: Text('/', style: TextStyle(fontSize: 28, color: Colors.white))),
      Expanded(child: calcField('Denominator', _den, hint: 'e.g. 6', type: TextInputType.number)),
    ]),
    const SizedBox(height: 16),
    calcBtn('Simplify', _calc, GemColors.warning),
    resultBox(_r, GemColors.warning),
  ]);
}

class LcmGcdCalc extends StatefulWidget {
  const LcmGcdCalc({super.key});
  @override State<LcmGcdCalc> createState() => _LcmGcdCalcState();
}
class _LcmGcdCalcState extends State<LcmGcdCalc> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _r;

  @override void dispose() { _a.dispose(); _b.dispose(); super.dispose(); }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  void _calc() {
    final a = int.tryParse(_a.text);
    final b = int.tryParse(_b.text);
    if (a == null || b == null || a == 0 || b == 0) return;
    final gcd = _gcd(a.abs(), b.abs());
    final lcm = (a.abs() * b.abs()) ~/ gcd;
    setState(() => _r = 'GCD: $gcd\nLCM: $lcm');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: calcField('First Number', _a, hint: 'e.g. 12', type: TextInputType.number)),
      const SizedBox(width: 12),
      Expanded(child: calcField('Second Number', _b, hint: 'e.g. 8', type: TextInputType.number)),
    ]),
    const SizedBox(height: 16),
    calcBtn('Calculate LCM & GCD', _calc, GemColors.warning),
    resultBox(_r, GemColors.warning),
  ]);
}

class PrimeChecker extends StatefulWidget {
  const PrimeChecker({super.key});
  @override State<PrimeChecker> createState() => _PrimeCheckerState();
}
class _PrimeCheckerState extends State<PrimeChecker> {
  final _n = TextEditingController();
  String? _r;

  @override void dispose() { _n.dispose(); super.dispose(); }

  bool _isPrime(int n) {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    for (int i = 3; i * i <= n; i += 2) { if (n % i == 0) return false; }
    return true;
  }

  List<int> _factors(int n) {
    final fs = <int>[];
    for (int i = 1; i <= n; i++) { if (n % i == 0) fs.add(i); }
    return fs;
  }

  void _calc() {
    final n = int.tryParse(_n.text);
    if (n == null) return;
    final prime = _isPrime(n);
    final factors = _factors(n);
    setState(() => _r = '$n is ${prime ? '✓ PRIME' : 'NOT prime'}\nFactors: ${factors.join(', ')}');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    calcField('Number', _n, hint: 'e.g. 97', type: TextInputType.number),
    const SizedBox(height: 16),
    calcBtn('Check', _calc, GemColors.warning),
    resultBox(_r, GemColors.warning),
  ]);
}

class RandomGen extends StatefulWidget {
  const RandomGen({super.key});
  @override State<RandomGen> createState() => _RandomGenState();
}
class _RandomGenState extends State<RandomGen> {
  final _min   = TextEditingController(text: '1');
  final _max   = TextEditingController(text: '100');
  final _count = TextEditingController(text: '1');
  String? _r;
  final _rng = math.Random();

  @override void dispose() { _min.dispose(); _max.dispose(); _count.dispose(); super.dispose(); }

  void _gen() {
    final lo = int.tryParse(_min.text);
    final hi = int.tryParse(_max.text);
    final n  = int.tryParse(_count.text);
    if (lo == null || hi == null || n == null || lo >= hi || n < 1 || n > 100) return;
    final nums = List.generate(n, (_) => lo + _rng.nextInt(hi - lo + 1));
    setState(() => _r = nums.join(', '));
  }

  void _coin() => setState(() => _r = _rng.nextBool() ? 'Heads' : 'Tails');
  void _dice() => setState(() => _r = '🎲 ${_rng.nextInt(6) + 1}');

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: calcField('Min', _min, hint: '1', type: TextInputType.number)),
      const SizedBox(width: 12),
      Expanded(child: calcField('Max', _max, hint: '100', type: TextInputType.number)),
      const SizedBox(width: 12),
      Expanded(child: calcField('Count', _count, hint: '1', type: TextInputType.number)),
    ]),
    const SizedBox(height: 16),
    calcBtn('Generate Numbers', _gen, GemColors.warning),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: ElevatedButton.icon(
        onPressed: _coin,
        style: ElevatedButton.styleFrom(
          backgroundColor: GemColors.accent.withValues(alpha: 0.15),
          foregroundColor: GemColors.accent,
          side: BorderSide(color: GemColors.accent.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.monetization_on_outlined, size: 16),
        label: const Text('Flip Coin'),
      )),
      const SizedBox(width: 10),
      Expanded(child: ElevatedButton.icon(
        onPressed: _dice,
        style: ElevatedButton.styleFrom(
          backgroundColor: GemColors.accent.withValues(alpha: 0.15),
          foregroundColor: GemColors.accent,
          side: BorderSide(color: GemColors.accent.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.casino_outlined, size: 16),
        label: const Text('Roll Dice'),
      )),
    ]),
    resultBox(_r, GemColors.warning),
  ]);
}
