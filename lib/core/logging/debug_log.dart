import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugLog {
  static void error(String text) {
    if (text.isEmpty) return;
    try {
      SharedPreferences.getInstance().then((prefs) {
        List<String> logs = prefs.getStringList('debug_logs') ?? [];
        logs.add('[${DateTime.now().toIso8601String()}] ERROR: $text');
        prefs.setStringList('debug_logs', logs);
      });
    } catch (_) {}
    debugPrint('\x1B[31m[X] $text\x1B[0m');
  }

  static void warning(String text) {
    if (text.isEmpty) return;
    try {
      SharedPreferences.getInstance().then((prefs) {
        List<String> logs = prefs.getStringList('debug_logs') ?? [];
        logs.add('[${DateTime.now().toIso8601String()}] WARNING: $text');
        prefs.setStringList('debug_logs', logs);
      });
    } catch (_) {}
    debugPrint('\x1B[33m[!] $text\x1B[0m');
  }

  static void success(String text) => text.isNotEmpty ? debugPrint('\x1B[32m[✓] $text\x1B[0m') : null;
  static void info(String text) => text.isNotEmpty ? debugPrint('\x1B[36m$text\x1B[0m') : null;
  static void alert(String text) => text.isNotEmpty ? debugPrint('\x1B[5m$text\x1B[0m') : null;
  static void tag(String text) => text.isNotEmpty ? debugPrint('\x1B[7m$text\x1B[0m') : null;

  /// Retorna los logs de error y warning almacenados en SharedPreferences
  static Future<List<String>> getDebugLogs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('debug_logs') ?? [];
  }

  static void clearLogs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('debug_logs');
  }
}
