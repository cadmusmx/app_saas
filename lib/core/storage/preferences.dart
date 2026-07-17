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
  bool? _vmES;
  bool? _lmRE; // null = el usuario aún no elige tipo (el form preguntará)
  bool? _rvSrAsk;
  ThemeMode _themeMode = ThemeMode.light;

  String get user => _user;
  bool? get vmES => _vmES;
  bool? get lmRE => _lmRE;
  bool? get rvSrAsk => _rvSrAsk;
  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
    _loadValues();
  }

  void _loadValues() {
    _user = _preferences?.getString(EPreferences.user.name) ?? '';
    _vmES = _preferences?.getBool(EPreferences.vmES.name);
    _lmRE = _preferences?.getBool(EPreferences.lmRE.name);
    _rvSrAsk = _preferences?.getBool(EPreferences.rvSrAsk.name);
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
    vmES = data[EPreferences.vmES.name];
    lmRE = data[EPreferences.lmRE.name];
    rvSrAsk = data[EPreferences.rvSrAsk.name];
  }

  Map<String, dynamic> toMap() {
    return {
      EPreferences.user.name: _user,
      EPreferences.vmES.name: _vmES,
      EPreferences.lmRE.name: _lmRE,
      EPreferences.rvSrAsk.name: _rvSrAsk,
    };
  }

  set user(String user) {
    _user = user;
    _preferences?.setString(EPreferences.user.name, user);
  }
  
  set vmES(bool? es) {
    _vmES = es;
    if (es != null) _preferences?.setBool(EPreferences.vmES.name, es);
  }

  set lmRE(bool? re) {
    _lmRE = re;
    if (re != null) _preferences?.setBool(EPreferences.lmRE.name, re);
  }

  set rvSrAsk(bool? srAsk) {
    _rvSrAsk = srAsk;
    if (srAsk != null) _preferences?.setBool(EPreferences.rvSrAsk.name, srAsk);
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
