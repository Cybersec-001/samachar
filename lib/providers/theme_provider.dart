import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  ThemeMode _mode;

  ThemeProvider(this._prefs)
      : _mode = ThemeMode.values.firstWhere(
          (m) => m.name == _prefs.getString('theme'),
          orElse: () => ThemeMode.system,
        );

  ThemeMode get mode => _mode;

  void toggle(Brightness current) {
    _mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    _prefs.setString('theme', _mode.name);
    notifyListeners();
  }
}
