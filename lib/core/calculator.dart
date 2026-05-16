import 'dart:math' as math;

class CalcException implements Exception {
  final String message;
  const CalcException(this.message);

  @override
  String toString() => message;
}

class Calculator {
  final String _src;
  int _pos = 0;

  Calculator._(this._src);

  static double evaluate(String expr) {
    final c = Calculator._(expr.trim());
    final v = c._expr();
    c._skipWs();
    if (c._pos != c._src.length) {
      throw CalcException(
        'Unexpected "${c._src[c._pos]}" at position ${c._pos}',
      );
    }
    return v;
  }

  double _expr() {
    var v = _term();
    while (true) {
      _skipWs();
      if (_pos >= _src.length) break;
      final ch = _src[_pos];
      if (ch == '+') {
        _pos++;
        v += _term();
      } else if (ch == '-') {
        _pos++;
        v -= _term();
      } else {
        break;
      }
    }
    return v;
  }

  double _term() {
    var v = _factor();
    while (true) {
      _skipWs();
      if (_pos >= _src.length) break;
      final ch = _src[_pos];
      if (ch == '*') {
        _pos++;
        v *= _factor();
      } else if (ch == '/') {
        _pos++;
        final r = _factor();
        if (r == 0) {
          throw const CalcException('Division by zero');
        }
        v /= r;
      } else if (ch == '%') {
        _pos++;
        v %= _factor();
      } else {
        break;
      }
    }
    return v;
  }

  double _factor() {
    var v = _unary();
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '^') {
      _pos++;
      // Recursive call (not _unary) makes ^ right-associative: 2^3^2 = 2^(3^2) = 512.
      v = math.pow(v, _factor()).toDouble();
    }
    return v;
  }

  double _unary() {
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '-') {
      _pos++;
      return -_unary();
    }
    if (_pos < _src.length && _src[_pos] == '+') {
      _pos++;
      return _unary();
    }
    return _primary();
  }

  double _primary() {
    _skipWs();
    if (_pos >= _src.length) {
      throw const CalcException('Unexpected end of expression');
    }

    final ch = _src[_pos];

    if (ch == '(') {
      _pos++;
      final v = _expr();
      _skipWs();
      if (_pos >= _src.length || _src[_pos] != ')') {
        throw CalcException('Expected ")" at position $_pos');
      }
      _pos++;
      return v;
    }

    if (_isDigit(ch) || ch == '.') {
      return _number();
    }

    if (_isAlpha(ch)) {
      return _functionOrConstant();
    }

    throw CalcException('Unexpected "$ch" at position $_pos');
  }

  double _number() {
    final start = _pos;
    while (_pos < _src.length &&
        (_isDigit(_src[_pos]) || _src[_pos] == '.')) {
      _pos++;
    }
    // Scientific notation: consume 'e'/'E' only if followed by digits or sign+digits.
    // Otherwise back up so 'e' can be parsed as Euler's constant by _functionOrConstant.
    if (_pos < _src.length &&
        (_src[_pos] == 'e' || _src[_pos] == 'E')) {
      final savedPos = _pos;
      _pos++;
      if (_pos < _src.length &&
          (_src[_pos] == '+' || _src[_pos] == '-')) {
        _pos++;
      }
      if (_pos < _src.length && _isDigit(_src[_pos])) {
        while (_pos < _src.length && _isDigit(_src[_pos])) {
          _pos++;
        }
      } else {
        _pos = savedPos;
      }
    }
    return double.parse(_src.substring(start, _pos));
  }

  double _functionOrConstant() {
    final start = _pos;
    while (_pos < _src.length && _isAlpha(_src[_pos])) {
      _pos++;
    }
    final name = _src.substring(start, _pos).toLowerCase();

    // Constants
    if (name == 'pi') return math.pi;
    if (name == 'e') return math.e;

    _skipWs();
    if (_pos >= _src.length || _src[_pos] != '(') {
      throw CalcException('Unknown identifier "$name"');
    }
    _pos++;
    final arg = _expr();
    _skipWs();
    if (_pos >= _src.length || _src[_pos] != ')') {
      throw CalcException('Expected ")" closing "$name"');
    }
    _pos++;

    switch (name) {
      case 'sqrt':
        return math.sqrt(arg);
      case 'abs':
        return arg.abs();
      case 'sin':
        return math.sin(arg);
      case 'cos':
        return math.cos(arg);
      case 'tan':
        return math.tan(arg);
      case 'log':
        return math.log(arg) / math.ln10;
      case 'ln':
        return math.log(arg);
      case 'exp':
        return math.exp(arg);
      case 'floor':
        return arg.floorToDouble();
      case 'ceil':
        return arg.ceilToDouble();
      case 'round':
        return arg.roundToDouble();
      default:
        throw CalcException('Unknown function "$name"');
    }
  }

  // Code-unit comparison is faster than character string comparisons for hot-path whitespace skipping.
  void _skipWs() {
    while (_pos < _src.length && _src.codeUnitAt(_pos) <= 32) {
      _pos++;
    }
  }

  bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  bool _isAlpha(String c) {
    final code = c.codeUnitAt(0);
    // 0x5F is underscore - included so identifiers like 'pi' and 'e' parse correctly.
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        code == 0x5F;
  }
}
