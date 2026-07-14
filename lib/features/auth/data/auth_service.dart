import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:gaso_tenant_app/core/auth/auth_token.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/http/api_exception.dart';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/tenant/tenant.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_storage.dart';
import 'package:gaso_tenant_app/core/services/fcm_service.dart';
import 'package:gaso_tenant_app/features/auth/data/me_service.dart';

enum AuthStatus { success, mfaRequired, mfaSetupRequired, failure }

class AuthResult {
  final AuthStatus status;
  // challengeId cuando status == mfaRequired
  // setupId      cuando status == mfaSetupRequired
  final String? sessionChallenge;
  final String? errorMessage;
  final int? statusCode; // HTTP del error (403/401/…), para decidir UI
  final String? errorCode; // code del BFF (TENANT_SUSPENDED, MFA_EXPIRED, …)
  final String? mfaSecretCode; // clave manual TOTP
  final String? mfaQrCodeUrl; // otpauth:// URI para el QR

  const AuthResult._({
    required this.status,
    this.sessionChallenge,
    this.errorMessage,
    this.statusCode,
    this.errorCode,
    this.mfaSecretCode,
    this.mfaQrCodeUrl,
  });

  factory AuthResult.success() => const AuthResult._(status: AuthStatus.success);

  factory AuthResult.mfa(String challengeId) =>
      AuthResult._(status: AuthStatus.mfaRequired, sessionChallenge: challengeId);

  factory AuthResult.mfaSetup(String setupId, {String? secretCode, String? qrCodeUrl}) => AuthResult._(
    status: AuthStatus.mfaSetupRequired,
    sessionChallenge: setupId,
    mfaSecretCode: secretCode,
    mfaQrCodeUrl: qrCodeUrl,
  );

  factory AuthResult.failure(String msg, {int? statusCode, String? errorCode}) =>
      AuthResult._(status: AuthStatus.failure, errorMessage: msg, statusCode: statusCode, errorCode: errorCode);
}

class AuthService with ChangeNotifier {
  AuthService._internal() {
    // Punto único de invalidación de sesión: un 401 en petición autenticada
    // (vía HttpService) cierra la sesión. S3 reutiliza esto tal cual.
    HttpService.onUnauthorized = _handleUnauthorized;
    _loadAuthState();
  }
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  static AuthService get instance => _instance;

  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'auth_token';
  static const _keyExpiry = 'auth_expiry';

  /// TTL por defecto si el BFF no envía `expiresIn` (no debería pasar; el
  /// contrato garantiza `expiresIn` en segundos). 24 h como respaldo.
  static const int _defaultSessionTtlSeconds = 24 * 60 * 60;

  final _api = _AuthApi();
  final _tenantStorage = TenantStorage();
  final _meService = MeService();

  bool _isAuthenticated = false;
  String? _token;
  DateTime? _tokenExpiry;
  final ValueNotifier<bool> loadedAuthState = ValueNotifier<bool>(false);

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  bool get isTokenValid => _tokenExpiry != null && _tokenExpiry!.isAfter(DateTime.now());

  Future<void> _loadAuthState() async {
    final token = await _storage.read(key: _keyToken);
    final expiry = await _storage.read(key: _keyExpiry);
    // Sesión válida = token (Bearer) presente + expiry vigente. El token es
    // imprescindible para llamar a rutas protegidas (/api/me en S3).
    if (token != null && token.isNotEmpty && expiry != null) {
      final expiryDate = DateTime.tryParse(expiry);
      if (expiryDate != null && expiryDate.isAfter(DateTime.now())) {
        _isAuthenticated = true;
        _token = token;
        _tokenExpiry = expiryDate;
        AuthToken.set(token);
        notifyListeners();
        await hydrateSession();
      } else {
        await _clearSecureData();
      }
    } else if (token != null || expiry != null) {
      await _clearSecureData(); // estado parcial/corrupto
    }
    loadedAuthState.value = true;
  }

  /// getMe() → AuthContext. Best-effort: un 401 ya cerró sesión vía HttpService.
  /// Devuelve true si la sesión RBAC quedó hidratada.
  Future<bool> hydrateSession() async {
    final res = await _meService.getMe();
    if (res.success && res.data != null) {
      AuthContext.instance.setSession(res.data!);
      return true;
    }
    DebugLog.warning('hydrateSession falló: ${res.message}');
    return false; // offline en cold-start: token válido pero sin views (ver §5)
  }

  /// Login conjunto (empresa + usuario + contraseña)
  /// POST /api/auth-mfa/start  { username, password }  + header x-tenant-slug
  ///   → mfaRequired(challengeId)        usuario con TOTP configurado
  ///   → mfaSetupRequired(setupId, ...)  usuario sin TOTP → flujo de configuración
  ///   → failure                         404 empresa / 403 suspendida / 401 credenciales
  Future<AuthResult> login(String slug, String username, String password) async {
    // Tenant parcial (solo slug) para que `x-tenant-slug` viaje en las llamadas
    // de auth. El tenant completo se hidrata desde la respuesta de /mobile/login.
    TenantContext.instance.setTenant(Tenant(id: '', slug: slug, name: slug, status: 'active'));

    try {
      final data = await _api.startMfaChallenge(username, password);

      if (data['requiresMfaSetup'] == true) {
        final setupData = await _api.startMfaSetup(username, password);

        // Caso borde: el factor ya estaba configurado → pedir challenge normal
        if (setupData['alreadyConfigured'] == true) {
          final retry = await _api.startMfaChallenge(username, password);
          final challengeId = retry['challengeId'] as String?;
          if (challengeId != null) return AuthResult.mfa(challengeId);
        }

        final setupId = setupData['setupId'] as String?;
        final otpauthUrl = setupData['otpauthUrl'] as String?;
        final manualKey = setupData['manualKey'] as String?;
        if (setupId == null) {
          return AuthResult.failure('Error al iniciar la configuración MFA.');
        }
        return AuthResult.mfaSetup(setupId, secretCode: manualKey, qrCodeUrl: otpauthUrl);
      }

      if (data['requiresMfa'] == true) {
        final challengeId = data['challengeId'] as String?;
        if (challengeId == null) return AuthResult.failure('Challenge inválido.');
        return AuthResult.mfa(challengeId);
      }

      return AuthResult.failure('Respuesta inesperada del servidor.');
    } on ApiException catch (e) {
      return AuthResult.failure(
        e.message.isNotEmpty ? e.message : 'No se pudo iniciar sesión.',
        statusCode: e.statusCode,
        errorCode: e.code,
      );
    } on SocketException {
      return AuthResult.failure('Sin conexión. Verifica tu internet.');
    } catch (e) {
      DebugLog.error('login $e');
      return AuthResult.failure('Ocurrió un error inesperado.');
    }
  }

  /// Verificar código MFA y emitir sesión
  Future<AuthResult> verifyMfa(String username, String password, String challengeId, String code) async {
    try {
      // POST /api/mobile/login { username, password, challengeId, mfaCode }
      final data = await _api.verifyLogin(username, password, challengeId, code);
      final userId = data['id'];
      final accessToken = data['accessToken'] as String?;
      if (userId == null || accessToken == null || accessToken.isEmpty) {
        return AuthResult.failure('Respuesta inválida del servidor.');
      }

      // Hidratar el tenant autoritativo desde la respuesta del login y persistir.
      final tenant = Tenant(
        id: (data['tenantId'] as String?) ?? TenantContext.instance.current?.id ?? '',
        slug: (data['tenantSlug'] as String?) ?? TenantContext.instance.current?.slug ?? '',
        name: (data['tenantName'] as String?) ?? '',
        status: 'active',
      );
      await _tenantStorage.save(tenant);
      TenantContext.instance.setTenant(tenant);

      //   éxito → { id, name, email, tenantId, tenantSlug, tenantName, accessToken, expiresIn }  (expiresIn en segundos)
      final ttlSeconds = (data['expiresIn'] as num?)?.toInt() ?? _defaultSessionTtlSeconds;
      await _saveToken(accessToken, ttlSeconds: ttlSeconds);
      await hydrateSession();

      return AuthResult.success();
    } on ApiException catch (e) {
      //   error → 401 MFA_INVALID/MFA_EXPIRED/INVALID_CREDENTIALS, 403 TENANT_SUSPENDED
      return AuthResult.failure(
        e.message.isNotEmpty ? e.message : 'Código MFA incorrecto.',
        statusCode: e.statusCode,
        errorCode: e.code,
      );
    } on SocketException {
      return AuthResult.failure('Sin conexión. Verifica tu internet.');
    } catch (e) {
      DebugLog.error('verifyMfa $e');
      return AuthResult.failure('Ocurrió un error inesperado.');
    }
  }

  Future<AuthResult> setupMfa(String username, String password, String setupId, String code) async {
    try {
      // POST /api/auth-mfa/setup/verify → verifica el factor
      final data = await _api.verifyMfaSetup(username, password, setupId, code);
      if (data['verified'] != true) {
        return AuthResult.failure('No se pudo confirmar la configuración.');
      }

      // POST /api/auth-mfa/start  → challengeId para completar el login
      final challengeData = await _api.startMfaChallenge(username, password);
      final challengeId = challengeData['challengeId'] as String?;
      if (challengeId == null) {
        return AuthResult.failure('No se pudo iniciar el desafío MFA tras la configuración.');
      }
      return AuthResult.mfa(challengeId);
    } on ApiException catch (e) {
      return AuthResult.failure(
        e.message.isNotEmpty ? e.message : 'Código incorrecto. Verifica tu app de autenticación.',
        statusCode: e.statusCode,
        errorCode: e.code,
      );
    } on SocketException {
      return AuthResult.failure('Sin conexión. Verifica tu internet.');
    } catch (e) {
      DebugLog.error('setupMfa $e');
      return AuthResult.failure('Ocurrió un error inesperado.');
    }
  }

  Future<void> logout() async {
    await _clearSecureData();
    AuthToken.clear();
    AuthContext.instance.clear();
    await FcmService().dispose();
    _isAuthenticated = false;
    _token = null;
    _tokenExpiry = null;
    notifyListeners();
  }

  /// Invocado por HttpService ante un 401 en petición autenticada.
  /// Solo invalida si hay sesión activa (un 401 durante el login no aplica).
  Future<void> _handleUnauthorized() async {
    if (!_isAuthenticated) return;
    DebugLog.error('AuthService: 401 recibido — sesión invalidada.');
    await logout();
  }

  Future<void> _saveToken(String token, {required int ttlSeconds}) async {
    final expiry = DateTime.now().add(Duration(seconds: ttlSeconds));
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyExpiry, value: expiry.toIso8601String());
    AuthToken.set(token);
    _isAuthenticated = true;
    _token = token;
    _tokenExpiry = expiry;
    notifyListeners();
  }

  Future<void> _clearSecureData() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyExpiry);
  }
}

class _AuthApi extends HttpService {
  /// POST /api/auth-mfa/start  { username, password }  (+ x-tenant-slug)
  ///   → { ok, requiresMfa, requiresMfaSetup, challengeId?, factorType }
  Future<Map<String, dynamic>> startMfaChallenge(String username, String password) async {
    final res = await send('POST', '/auth-mfa/start', body: {'username': username, 'password': password});
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /api/auth-mfa/setup/start  { username, password }
  ///   → { ok, setupId, otpauthUrl, manualKey } | { ok, alreadyConfigured }
  Future<Map<String, dynamic>> startMfaSetup(String username, String password) async {
    final res = await send('POST', '/auth-mfa/setup/start', body: {'username': username, 'password': password});
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /api/mobile/login  { username, password, challengeId, mfaCode }
  ///   → { id, name, email, tenantId, tenantSlug, tenantName, accessToken, expiresIn }
  Future<Map<String, dynamic>> verifyLogin(String username, String password, String challengeId, String mfaCode) async {
    final res = await send(
      'POST',
      '/mobile/login',
      body: {'username': username, 'password': password, 'challengeId': challengeId, 'mfaCode': mfaCode},
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /api/auth-mfa/setup/verify  { username, password, setupId, mfaCode }
  ///   → { ok, verified }
  Future<Map<String, dynamic>> verifyMfaSetup(String username, String password, String setupId, String mfaCode) async {
    final res = await send(
      'POST',
      '/auth-mfa/setup/verify',
      body: {'username': username, 'password': password, 'setupId': setupId, 'mfaCode': mfaCode},
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
