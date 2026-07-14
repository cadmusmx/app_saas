import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaso_tenant_app/core/storage/preferences_enum.dart';

/// Data que podría permanecer independiente a la sesión
class Preferences {
  static final Preferences _instance = Preferences._internal();
  factory Preferences() => _instance;
  Preferences._internal();

  SharedPreferences? _preferences;
  String _user = '';
  ThemeMode _themeMode = ThemeMode.light;

  String get user => _user;
  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
    _loadValues();
  }

  void _loadValues() {
    _user = _preferences?.getString(EPreferences.user.name) ?? '';
    _themeMode = _parseThemeMode(_preferences?.getString(EPreferences.themeMode.name));
  }

  /// Borra credenciales de sesión, conserva preferencias del dispositivo como vmES
  Future<void> clearSession() async {
    await _preferences?.remove(EPreferences.user.name);
    _user = '';
  }

  /// Borra todo
  Future<void> clearAll() async {
    await _preferences?.clear();
    _loadValues();
  }

  void fromMap(Map<String, dynamic> data) {
    user = data[EPreferences.user.name];
  }

  Map<String, dynamic> toMap() {
    return {
      EPreferences.user.name: _user,
    };
  }

  set user(String user) {
    _user = user;
    _preferences?.setString(EPreferences.user.name, user);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _preferences?.setString(EPreferences.themeMode.name, mode.name);
  }

  static ThemeMode _parseThemeMode(String? value) {
    return switch (value) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light, // default
    };
  }
}
