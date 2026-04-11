import 'package:flutter/material.dart';

/// A simple [ChangeNotifier] that holds the current [ThemeMode].
///
/// Injected at the root of the widget tree so any descendant can
/// toggle between light‑, dark‑, and system‑default themes.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark; // default to the gorgeous dark mode

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
    }
  }
}
