import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePrefs extends ChangeNotifier {
  static final ThemePrefs instance = ThemePrefs._();
  ThemePrefs._();

  static const _kAccent = 'theme_accent';

  static const List<({String name, Color color})> palette = [
    (name: 'Lavender', color: Color(0xFF9B8BFF)),
    (name: 'Ice Blue', color: Color(0xFF6BCFFF)),
    (name: 'Emerald',  color: Color(0xFF6BFFB8)),
    (name: 'Amber',    color: Color(0xFFFFD166)),
    (name: 'Rose',     color: Color(0xFFFF6B8A)),
    (name: 'Orange',   color: Color(0xFFFF9E64)),
    (name: 'Teal',     color: Color(0xFF5EE7D0)),
  ];

  Color _accent = const Color(0xFF9B8BFF);
  Color get accent => _accent;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final val = p.getInt(_kAccent);
    if (val != null) {
      _accent = Color(val);
      notifyListeners();
    }
  }

  Future<void> setAccent(Color c) async {
    if (_accent == c) return;
    _accent = c;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    // Color.value is deprecated but SharedPreferences has no typed Color API;
    // storing as int is the only way to round-trip a Color without a custom serializer.
    // ignore: deprecated_member_use
    await p.setInt(_kAccent, c.value);
  }
}
