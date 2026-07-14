import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // Constructor privado que inicializa el contador
  NotificationService._internal() {
    _initCount();
  }

  final String notificationsKey = 'GNotifications';
  final ValueNotifier<int> notificationCount = ValueNotifier<int>(0);

  // Inicializa el contador al crear la instancia
  Future<void> _initCount() async {
    notificationCount.value = await getNotificationCount();
  }

  // Actualiza el contador
  Future<void> _updateCount() async {
    notificationCount.value = await getNotificationCount();
  }

  /// Obtiene todas las notificaciones guardadas
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      List<String>? notifications = preferences.getStringList(notificationsKey);
      if (notifications == null || notifications.isEmpty) return [];
      return notifications
          .map((n) {
            try {
              return Map<String, dynamic>.from(jsonDecode(n));
            } catch (e) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      DebugLog.error('Error obteniendo notificaciones: $e');
      return [];
    }
  }

  /// Guarda una nueva notificación
  Future<bool> saveNotification(String title, String body, String timestamp) async {
    try {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      List<String> notifications = preferences.getStringList(notificationsKey) ?? [];
      notifications.add(jsonEncode({'title': title, 'body': body, 'timestamp': timestamp}));
      final result = await preferences.setStringList(notificationsKey, notifications);

      if (result) await _updateCount();

      return result;
    } catch (e) {
      DebugLog.error('Error guardando notificación: $e');
      return false;
    }
  }

  /// Elimina una notificación por índice
  Future<bool> deleteNotification(int index) async {
    try {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      List<String> notifications = preferences.getStringList(notificationsKey) ?? [];
      if (index < 0 || index >= notifications.length) return false;
      notifications.removeAt(index);
      final result = await preferences.setStringList(notificationsKey, notifications);

      if (result) await _updateCount();

      return result;
    } catch (e) {
      DebugLog.error('Error eliminando notificación: $e');
      return false;
    }
  }

  /// Elimina todas las notificaciones
  Future<bool> clearAllNotifications() async {
    try {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      final result = await preferences.remove(notificationsKey);

      if (result) await _updateCount();

      return result;
    } catch (e) {
      DebugLog.error('Error limpiando notificaciones: $e');
      return false;
    }
  }

  /// Obtiene el número de notificaciones guardadas
  Future<int> getNotificationCount() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(notificationsKey)?.length ?? 0;
  }

  /// Limpia recursos
  void dispose() {
    notificationCount.dispose();
  }
}
