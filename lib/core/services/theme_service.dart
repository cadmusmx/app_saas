import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/core/storage/preferences.dart';

class ThemeService with ChangeNotifier {
  final Preferences _preferences = Preferences();
  ThemeMode _themeMode = ThemeMode.light;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get loaded => _loaded;

  ThemeService() {
    _load();
  }

  Future<void> _load() async {
    await _preferences.init();
    _themeMode = _preferences.themeMode;
    _loaded = true;
    notifyListeners();
  }

  /// Cambia entre light y dark (no toca system).
  Future<void> toggleDark() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  Future<void> setMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _preferences.setThemeMode(mode);
  }
}
