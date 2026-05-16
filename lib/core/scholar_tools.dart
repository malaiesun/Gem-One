import 'dart:math' as math;

class ScholarTools {
  // Handles: ax+b=c  and  ax²+bx+c=0
  static String solve(String eq) {
    final s = eq.trim().replaceAll(' ', '');
    if (s.isEmpty) return 'No equation provided.';

    // Quadratic: contains x² or x^2
    if (s.contains('x²') || s.contains('x^2') || s.contains('x2')) {
      return _solveQuadratic(s);
    }
    // Linear
    return _solveLinear(s);
  }

  static String _solveLinear(String eq) {
    // Normalize: move everything to ax + b = 0 form
    // Supported: ax+b=c  or  ax=b  or  x+b=c
    try {
      final sides = _splitEq(eq);
      if (sides == null) return 'Could not parse equation "$eq". Use format: ax+b=c';

      // Collect x and constant coefficients
      double xCoef = 0, constant = 0;
      _parseLinearSide(sides[0],  1, out: (x, c) { xCoef += x; constant += c; });
      _parseLinearSide(sides[1], -1, out: (x, c) { xCoef += x; constant += c; });

      if (xCoef == 0) {
        return constant == 0 ? 'Infinitely many solutions (identity).' : 'No solution (contradiction).';
      }

      final x = -constant / xCoef;
      return 'x = ${_fmt(x)}';
    } catch (_) {
      return 'Could not solve "$eq". Ensure it is in linear form ax+b=c.';
    }
  }

  static List<String>? _splitEq(String eq) {
    final idx = eq.indexOf('=');
    if (idx < 0) return null;
    return [eq.substring(0, idx), eq.substring(idx + 1)];
  }

  static void _parseLinearSide(
    String expr,
    // sign = +1 for LHS, -1 for RHS - negates RHS terms to move them to LHS.
    int sign,
    {required void Function(double x, double c) out}
  ) {
    final re = RegExp(r'([+-]?\d*\.?\d*)[xX]|([+-]?\d+\.?\d*)');
    for (final m in re.allMatches(expr)) {
      if (m.group(1) != null) {
        final coefStr = m.group(1)!;
        final coef = coefStr.isEmpty || coefStr == '+' ? 1.0
            : coefStr == '-' ? -1.0
            : double.parse(coefStr);
        out(sign * coef, 0);
      } else if (m.group(2) != null) {
        out(0, sign * double.parse(m.group(2)!));
      }
    }
  }

  static String _solveQuadratic(String eq) {
    try {
      final sides = _splitEq(eq);
      if (sides == null) return 'Could not parse quadratic.';

      // Move RHS to LHS: ax²+bx+c=0
      double a = 0, b = 0, c = 0;
      _parseQuadSide(sides[0],  1, (qa, qb, qc) { a += qa; b += qb; c += qc; });
      _parseQuadSide(sides[1], -1, (qa, qb, qc) { a += qa; b += qb; c += qc; });

      if (a == 0) return _solveLinear('${b}x+$c=0');

      final disc = b * b - 4 * a * c;
      if (disc < 0) {
        final re = -b / (2 * a);
        final im = math.sqrt(-disc) / (2 * a);
        return 'x = ${_fmt(re)} + ${_fmt(im)}i  or  x = ${_fmt(re)} - ${_fmt(im)}i  (complex roots)';
      }
      final sqrtDisc = math.sqrt(disc);
      final x1 = (-b + sqrtDisc) / (2 * a);
      final x2 = (-b - sqrtDisc) / (2 * a);
      // Epsilon comparison because floating-point arithmetic rarely produces exactly equal roots.
      if ((x1 - x2).abs() < 1e-9) return 'x = ${_fmt(x1)}  (double root)';
      return 'x = ${_fmt(x1)}  or  x = ${_fmt(x2)}';
    } catch (_) {
      return 'Could not solve quadratic "$eq".';
    }
  }

  static void _parseQuadSide(String expr, int sign,
      void Function(double a, double b, double c) out) {
    double a = 0, b = 0, c = 0;
    final re = RegExp(r'([+-]?\d*\.?\d*)[xX][²2^]2?|([+-]?\d*\.?\d*)[xX]|([+-]?\d+\.?\d*)');
    for (final m in re.allMatches(expr)) {
      if (m.group(1) != null) {
        final coefStr = m.group(1)!.replaceAll('^', '');
        final coef = coefStr.isEmpty || coefStr == '+' ? 1.0
            : coefStr == '-' ? -1.0
            : double.tryParse(coefStr) ?? 1.0;
        a += sign * coef;
      } else if (m.group(2) != null) {
        final coefStr = m.group(2)!;
        final coef = coefStr.isEmpty || coefStr == '+' ? 1.0
            : coefStr == '-' ? -1.0
            : double.tryParse(coefStr) ?? 1.0;
        b += sign * coef;
      } else if (m.group(3) != null) {
        c += sign * double.parse(m.group(3)!);
      }
    }
    out(a, b, c);
  }

  // Handles: prime factorization, GCF, LCM
  // Input examples: "120"  |  "gcf 12 18"  |  "lcm 4 6 8"
  static String factor(String input) {
    final s = input.trim().toLowerCase();
    if (s.isEmpty) return 'No input provided.';

    if (s.startsWith('gcf') || s.startsWith('gcd')) {
      final nums = _extractInts(s.replaceFirst(RegExp(r'^gc[fd]\s*'), ''));
      if (nums.length < 2) return 'Provide at least 2 numbers for GCF.';
      final g = nums.reduce(_gcd);
      return 'GCF(${nums.join(', ')}) = $g';
    }

    if (s.startsWith('lcm')) {
      final nums = _extractInts(s.replaceFirst(RegExp(r'^lcm\s*'), ''));
      if (nums.length < 2) return 'Provide at least 2 numbers for LCM.';
      final l = nums.reduce(_lcm);
      return 'LCM(${nums.join(', ')}) = $l';
    }

    // Prime factorization
    final nums = _extractInts(s);
    if (nums.isEmpty) return 'Could not parse number from "$input".';
    final n = nums.first;
    if (n <= 1) return '$n has no prime factors.';
    final factors = _primeFactors(n);
    final grouped = _groupFactors(factors);
    return 'Prime factors of $n: ${grouped.join(' x ')}';
  }

  static List<int> _extractInts(String s) {
    return RegExp(r'\d+').allMatches(s).map((m) => int.parse(m.group(0)!)).toList();
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
  static int _lcm(int a, int b) => (a * b) ~/ _gcd(a, b);

  static List<int> _primeFactors(int n) {
    final factors = <int>[];
    for (int d = 2; d * d <= n; d++) {
      while (n % d == 0) { factors.add(d); n ~/= d; }
    }
    if (n > 1) factors.add(n);
    return factors;
  }

  static List<String> _groupFactors(List<int> factors) {
    final counts = <int, int>{};
    for (final f in factors) { counts[f] = (counts[f] ?? 0) + 1; }
    return counts.entries.map((e) => e.value == 1 ? '${e.key}' : '${e.key}^${e.value}').toList();
  }

  // Input: comma-separated numbers
  static String stats(String input) {
    final parts = input.split(RegExp(r'[,\s]+'))
        .map((p) => double.tryParse(p.trim()))
        .whereType<double>()
        .toList();

    if (parts.isEmpty) return 'No valid numbers found in "$input".';

    parts.sort();
    final n = parts.length;
    final mean = parts.reduce((a, b) => a + b) / n;
    final median = n.isOdd
        ? parts[n ~/ 2]
        : (parts[n ~/ 2 - 1] + parts[n ~/ 2]) / 2;

    // Mode
    final counts = <double, int>{};
    for (final v in parts) { counts[v] = (counts[v] ?? 0) + 1; }
    final maxCount = counts.values.reduce(math.max);
    final modes = counts.entries.where((e) => e.value == maxCount).map((e) => e.key).toList()..sort();

    final variance = parts.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / n;
    final stdDev   = math.sqrt(variance);
    final range    = parts.last - parts.first;

    final buf = StringBuffer();
    buf.writeln('n = $n');
    buf.writeln('Mean   = ${_fmt(mean)}');
    buf.writeln('Median = ${_fmt(median)}');
    buf.writeln('Mode   = ${modes.length == n ? "none" : modes.map(_fmt).join(", ")}');
    buf.writeln('Range  = ${_fmt(range)}');
    buf.writeln('Variance = ${_fmt(variance)}');
    buf.write('Std Dev  = ${_fmt(stdDev)}');
    return buf.toString();
  }

  // Input: "5 km to miles" | "100 f to c" | "3.5 kg to lbs"
  static String convert(String input) {
    final s = input.trim().toLowerCase();

    final re = RegExp(r'^([\d.]+)\s*([a-z°²³/]+(?:\s+[a-z]+)?)\s+to\s+([a-z°²³/]+(?:\s+[a-z]+)?)$');
    final m = re.firstMatch(s);
    if (m == null) {
      return 'Format: <value> <from_unit> to <to_unit>. Example: 5 km to miles';
    }

    final value = double.tryParse(m.group(1)!);
    if (value == null) return 'Invalid number.';
    final fromUnit = m.group(2)!.trim();
    final toUnit   = m.group(3)!.trim();

    final result = _convertUnits(value, fromUnit, toUnit);
    if (result == null) return 'Conversion from "$fromUnit" to "$toUnit" is not supported.';

    return '${_fmt(value)} $fromUnit = ${_fmt(result)} $toUnit';
  }

  static double? _convertUnits(double v, String from, String to) {
    // Convert to SI base, then to target
    final toSI   = _toSI(v, from);
    if (toSI == null) return null;
    return _fromSI(toSI.$1, toSI.$2, to);
  }

  // Returns (value_in_SI, dimension) or null
  static (double, String)? _toSI(double v, String u) {
    switch (u) {
      // Length (base: m)
      case 'km': case 'kilometers': case 'kilometre':   return (v * 1000, 'length');
      case 'm':  case 'meters': case 'metre':           return (v, 'length');
      case 'cm': case 'centimeters':                    return (v / 100, 'length');
      case 'mm': case 'millimeters':                    return (v / 1000, 'length');
      case 'mi': case 'miles': case 'mile':             return (v * 1609.344, 'length');
      case 'ft': case 'feet': case 'foot':              return (v * 0.3048, 'length');
      case 'in': case 'inches': case 'inch':            return (v * 0.0254, 'length');
      case 'yd': case 'yards': case 'yard':             return (v * 0.9144, 'length');
      // Mass (base: kg)
      case 'kg': case 'kilograms': case 'kilogram':     return (v, 'mass');
      case 'g':  case 'grams': case 'gram':             return (v / 1000, 'mass');
      case 'mg': case 'milligrams':                     return (v / 1e6, 'mass');
      case 'lb': case 'lbs': case 'pounds': case 'pound': return (v * 0.453592, 'mass');
      case 'oz': case 'ounces': case 'ounce':           return (v * 0.0283495, 'mass');
      case 't':  case 'tonnes': case 'tonne':           return (v * 1000, 'mass');
      // Volume (base: L)
      case 'l':  case 'liters': case 'liter': case 'litre':    return (v, 'volume');
      case 'ml': case 'milliliters': case 'milliliter':         return (v / 1000, 'volume');
      case 'gal': case 'gallons': case 'gallon':                return (v * 3.78541, 'volume');
      case 'fl oz': case 'fl_oz': case 'floz':                  return (v * 0.0295735, 'volume');
      case 'cup': case 'cups':                                   return (v * 0.236588, 'volume');
      // Temperature has a non-zero offset so it can't use the SI multiply/divide pattern.
      case 'c': case 'celsius': case '°c':  return (v, 'temp');
      case 'f': case 'fahrenheit': case '°f': return ((v - 32) * 5 / 9, 'temp');
      case 'k': case 'kelvin':              return (v - 273.15, 'temp');
      // Speed (base: m/s)
      case 'km/h': case 'kph': case 'kmh': return (v / 3.6, 'speed');
      case 'm/s': case 'ms':               return (v, 'speed');
      case 'mph': case 'mi/h':             return (v * 0.44704, 'speed');
      case 'knots': case 'knot':           return (v * 0.514444, 'speed');
      // Energy (base: J)
      case 'j':  case 'joules':            return (v, 'energy');
      case 'kj': case 'kilojoules':        return (v * 1000, 'energy');
      case 'cal': case 'calories':         return (v * 4.184, 'energy');
      case 'kcal': case 'kilocalories':    return (v * 4184, 'energy');
      case 'wh': case 'watt-hours':        return (v * 3600, 'energy');
      case 'kwh': case 'kilowatt-hours':   return (v * 3.6e6, 'energy');
      // Area (base: m²)
      case 'm2': case 'm²': case 'sqm':   return (v, 'area');
      case 'km2': case 'km²':             return (v * 1e6, 'area');
      case 'cm2': case 'cm²':             return (v / 1e4, 'area');
      case 'ft2': case 'ft²': case 'sqft': return (v * 0.092903, 'area');
      case 'acre': case 'acres':           return (v * 4046.86, 'area');
      case 'ha': case 'hectares': case 'hectare': return (v * 1e4, 'area');
      default: return null;
    }
  }

  static double? _fromSI(double v, String dim, String to) {
    switch (to) {
      // Length
      case 'km': case 'kilometers': case 'kilometre':   return dim == 'length' ? v / 1000 : null;
      case 'm':  case 'meters': case 'metre':           return dim == 'length' ? v : null;
      case 'cm': case 'centimeters':                    return dim == 'length' ? v * 100 : null;
      case 'mm': case 'millimeters':                    return dim == 'length' ? v * 1000 : null;
      case 'mi': case 'miles': case 'mile':             return dim == 'length' ? v / 1609.344 : null;
      case 'ft': case 'feet': case 'foot':              return dim == 'length' ? v / 0.3048 : null;
      case 'in': case 'inches': case 'inch':            return dim == 'length' ? v / 0.0254 : null;
      case 'yd': case 'yards': case 'yard':             return dim == 'length' ? v / 0.9144 : null;
      // Mass
      case 'kg': case 'kilograms':                      return dim == 'mass' ? v : null;
      case 'g':  case 'grams':                          return dim == 'mass' ? v * 1000 : null;
      case 'mg': case 'milligrams':                     return dim == 'mass' ? v * 1e6 : null;
      case 'lb': case 'lbs': case 'pounds':             return dim == 'mass' ? v / 0.453592 : null;
      case 'oz': case 'ounces':                         return dim == 'mass' ? v / 0.0283495 : null;
      case 't':  case 'tonnes':                         return dim == 'mass' ? v / 1000 : null;
      // Volume
      case 'l':  case 'liters': case 'litre':           return dim == 'volume' ? v : null;
      case 'ml': case 'milliliters':                    return dim == 'volume' ? v * 1000 : null;
      case 'gal': case 'gallons':                       return dim == 'volume' ? v / 3.78541 : null;
      case 'fl oz': case 'fl_oz': case 'floz':          return dim == 'volume' ? v / 0.0295735 : null;
      case 'cup': case 'cups':                          return dim == 'volume' ? v / 0.236588 : null;
      // Temperature
      case 'c': case 'celsius': case '°c':  return dim == 'temp' ? v : null;
      case 'f': case 'fahrenheit': case '°f': return dim == 'temp' ? v * 9 / 5 + 32 : null;
      case 'k': case 'kelvin':              return dim == 'temp' ? v + 273.15 : null;
      // Speed
      case 'km/h': case 'kph':             return dim == 'speed' ? v * 3.6 : null;
      case 'm/s':                           return dim == 'speed' ? v : null;
      case 'mph': case 'mi/h':             return dim == 'speed' ? v / 0.44704 : null;
      case 'knots':                         return dim == 'speed' ? v / 0.514444 : null;
      // Energy
      case 'j':  case 'joules':            return dim == 'energy' ? v : null;
      case 'kj': case 'kilojoules':        return dim == 'energy' ? v / 1000 : null;
      case 'cal': case 'calories':         return dim == 'energy' ? v / 4.184 : null;
      case 'kcal': case 'kilocalories':    return dim == 'energy' ? v / 4184 : null;
      case 'wh': case 'watt-hours':        return dim == 'energy' ? v / 3600 : null;
      case 'kwh': case 'kilowatt-hours':   return dim == 'energy' ? v / 3.6e6 : null;
      // Area
      case 'm2': case 'm²': case 'sqm':   return dim == 'area' ? v : null;
      case 'km2': case 'km²':             return dim == 'area' ? v / 1e6 : null;
      case 'cm2': case 'cm²':             return dim == 'area' ? v * 1e4 : null;
      case 'ft2': case 'ft²': case 'sqft': return dim == 'area' ? v / 0.092903 : null;
      case 'acre': case 'acres':           return dim == 'area' ? v / 4046.86 : null;
      case 'ha': case 'hectares':          return dim == 'area' ? v / 1e4 : null;
      default: return null;
    }
  }

  static String _fmt(double v) {
    if (v.isInfinite || v.isNaN) return v.toString();
    if (v == v.truncateToDouble() && v.abs() < 1e12) return v.toInt().toString();
    // Up to 6 significant figures, strip trailing zeros
    final s = v.toStringAsPrecision(6);
    if (s.contains('.')) {
      return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
