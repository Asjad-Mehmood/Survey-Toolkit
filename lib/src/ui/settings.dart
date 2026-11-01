import 'package:flutter/material.dart';

import '../state/store.dart';

/// The user's settings, remembered on this PC: light, dark or as Windows.
class AppSettings extends ChangeNotifier {
  AppSettings([Store? store]) : _store = store ?? Store.memory() {
    final j = _store.readJson(_key) ?? const {};
    _themeMode = ThemeMode.values.asNameMap()[j['theme']] ?? ThemeMode.system;
  }

  final Store _store;
  static const _key = 'settings';
  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    _store.writeJson(_key, {'theme': _themeMode.name});
    notifyListeners();
  }

  /// The theme button: from what is showing now to the other one
  void cycleTheme(Brightness showing) => themeMode = showing == Brightness.light ? ThemeMode.dark : ThemeMode.light;
}
