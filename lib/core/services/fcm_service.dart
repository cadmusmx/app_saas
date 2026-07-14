import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';

/// Servicio singleton para gestionar el ciclo de vida de Firebase Cloud Messaging.
///
/// [initialize] es idempotente:
/// - Primera llamada: pide permisos, obtiene el token inicial y registra los
///   listeners de `onMessage`, `onMessageOpenedApp` y `onTokenRefresh`.
/// - Llamadas siguientes: solo refrescan las referencias a los callbacks
///   (porque el widget puede haberse remontado y tener un `this` distinto),
///   pero NO re-registran listeners.
///
/// Esto evita el bug de notificaciones duplicadas cuando HomeScreen se
/// re-monta por rebuild del AuthWrapper.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  bool _initialized = false;

  Future<void> Function(String token)? _onToken;
  void Function(RemoteMessage message, {required bool fromBackground})? _onMessage;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  Future<void> initialize({
    Future<void> Function(String token)? onToken,
    void Function(RemoteMessage message, {required bool fromBackground})? onMessage,
  }) async {
    // Siempre refrescar callbacks: el widget cliente puede haberse remontado.
    _onToken = onToken;
    _onMessage = onMessage;

    if (_initialized) return;

    try {
      await _ensureFirebaseReady();

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        DebugLog.success('Permiso de notificaciones concedido');
      } else {
        DebugLog.warning('Permiso de notificaciones NO concedido: ${settings.authorizationStatus}');
      }

      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          DebugLog.info('FCM token inicial: $token');
          await _onToken?.call(token);
        } else {
          DebugLog.error('No se pudo obtener el token FCM (null).');
        }
      } catch (e) {
        DebugLog.error('Error al obtener token FCM: $e');
      }

      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) async {
          DebugLog.info('FCM token refrescado: $newToken');
          await _onToken?.call(newToken);
        },
        onError: (error) {
          DebugLog.error('Error en token refresh: $error');
        },
      );

      // Notificación que abrió la app cuando estaba cerrada
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          DebugLog.info('App abierta desde notificación (app cerrada)');
          _onMessage?.call(message, fromBackground: true);
        }
      });

      _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) {
          DebugLog.info('App abierta desde notificación (app en segundo plano)');
          _onMessage?.call(message, fromBackground: true);
        },
      );

      _messageSub = FirebaseMessaging.onMessage.listen(
        (message) {
          DebugLog.info('Notificación recibida en primer plano');
          _onMessage?.call(message, fromBackground: false);
        },
      );

      _initialized = true;
    } catch (e) {
      DebugLog.error('Error general en configuración de notificaciones: $e');
    }
  }

  /// Cancela todas las suscripciones y reinicia el estado.
  /// Útil si en el futuro se necesita tumbar el servicio al cerrar sesión.
  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _messageSub?.cancel();
    await _messageOpenedSub?.cancel();
    _tokenRefreshSub = null;
    _messageSub = null;
    _messageOpenedSub = null;
    _onToken = null;
    _onMessage = null;
    _initialized = false;
  }

  Future<void> _ensureFirebaseReady() async {
    try {
      Firebase.app();
    } catch (_) {
      await Firebase.initializeApp();
    }
  }
}
