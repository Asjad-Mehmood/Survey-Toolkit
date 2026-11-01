// What the app remembers on this device: settings, the last inputs and the project plate.
// Windows keeps it in the user's AppData folder, the web app in the browser's storage.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Store {
  Store(this._prefs);

  /// A store that forgets everything when the app closes: for tests and when storage is blocked
  Store.memory() : _prefs = null;

  final SharedPreferences? _prefs;
  final Map<String, String> _memory = {};

  static const _prefix = 'toolkit.';

  static Future<Store> open() async {
    try {
      return Store(await SharedPreferences.getInstance());
    } catch (_) {
      // a private browser window can refuse storage: work without remembering
      return Store.memory();
    }
  }

  String? read(String key) => _prefs?.getString('$_prefix$key') ?? _memory[key];

  void write(String key, String value) {
    _memory[key] = value;
    // a full browser storage refuses: kept for this session only
    _prefs?.setString('$_prefix$key', value).catchError((_) => false);
  }

  void remove(String key) {
    _memory.remove(key);
    _prefs?.remove('$_prefix$key');
  }

  Map<String, Object?>? readJson(String key) {
    final raw = read(key);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, Object?> ? v : null;
    } on FormatException {
      return null;
    }
  }

  void writeJson(String key, Map<String, Object?> value) => write(key, jsonEncode(value));
}
