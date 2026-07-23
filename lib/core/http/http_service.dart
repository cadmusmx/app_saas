import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:gaso_tenant_app/core/auth/auth_token.dart';
import 'package:gaso_tenant_app/core/http/api_exception.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/core/tenant/tenant.dart';

abstract class HttpService {
  final Client _client;
  final bool allowSelfSigned;

  static const Duration _timeout = Duration(seconds: 25);

  /// Hook global de sesión inválida (HTTP 401 en una petición autenticada).
  /// Lo registra [AuthService] en el arranque.
  /// Vive en `core/` y se invoca por callback para no crear una dependencia core -> features.
  /// Es la base del manejo de 401 que consume S3.
  static Future<void> Function()? onUnauthorized;

  HttpService({Client? client, this.allowSelfSigned = false}) : _client = client ?? Client();

  /// Solo Content-Type + origen — usado por [sendNoTenant] (sin tenant ni auth).
  /// `x-origin-id: 3` identifica a la app móvil para la auditoría del BFF.
  Map<String, String> get _baseHeaders => {'Content-Type': 'application/json', 'x-origin-id': '3'};

  /// Headers completos: tenant (id + slug + name) + Bearer token.
  /// El BFF Next.js usa los tres headers de tenant para SetTenantContext.
  Map<String, String> get _headers {
    final h = Map<String, String>.from(_baseHeaders);
    final tenant = TenantContext.instance.current;
    if (tenant != null) {
      h['x-tenant-id'] = tenant.id;
      h[Config.tenantHeaderName] = tenant.slug; // x-tenant-slug
      h['x-tenant-name'] = tenant.name;
    }
    final token = AuthToken.value;
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// Llamada estándar: incluye headers de tenant y Authorization.
  /// Un 401 en estas peticiones dispara [onUnauthorized] (sesión expirada).
  Future<Response> send(String method, String endpoint, {Map<String, dynamic>? body, bool useIOClient = false}) {
    return _execute(method, endpoint, headers: _headers, body: body, useIOClient: useIOClient, authenticated: true);
  }

  /// Llamada sin tenant ni token — para endpoints públicos como resolve-tenant
  /// y el flujo de login/MFA. Un 401 aquí NO invalida sesión (no hay sesión aún).
  Future<Response> sendNoTenant(String method, String endpoint, {Map<String, dynamic>? body}) {
    return _execute(method, endpoint, headers: _baseHeaders, body: body, authenticated: false);
  }

  String getApiUrl() {
    final Tenant? tenantContext = TenantContext.instance.current;
    if (tenantContext == null) return Config.apiUrl;
    final String slug = tenantContext.slug;
    return 'https://$slug:3000/api/';
  }

  // Implementación interna

  Future<Response> _execute(
    String method,
    String endpoint, {
    required Map<String, String> headers,
    required bool authenticated,
    Map<String, dynamic>? body,
    bool useIOClient = false,
  }) async {
    final prodApiUrl = getApiUrl(); // temp
    DebugLog.info('API en producción: $prodApiUrl'); // temp
    final apiUrl = Config.appEnv == AppEnv.prod ? getApiUrl() : Config.apiUrl;
    final uri = Uri.parse('$apiUrl$endpoint');
    final encodedBody = body != null ? jsonEncode(body) : null;
    final client = useIOClient ? buildClient() : _client;

    try {
      final response = await _performRequest(client, method, uri, encodedBody, body, headers);
      await _validateResponse(response, uri, authenticated: authenticated);
      return response;
    } on SocketException {
      DebugLog.error('HttpService: sin conexión ($uri)');
      throw const ApiException('Sin conexión con el servidor.');
    } on TimeoutException {
      DebugLog.error('HttpService: timeout ($uri)');
      throw const ApiException('El servidor tardó demasiado en responder.');
    } on HttpException {
      rethrow;
    } catch (e) {
      DebugLog.error('HttpService error: $e');
      rethrow;
    } finally {
      if (useIOClient) client.close();
    }
  }

  Future<Response> _performRequest(
    Client client,
    String method,
    Uri uri,
    String? encodedBody,
    Map<String, dynamic>? body,
    Map<String, String> headers,
  ) async {
    switch (method.toUpperCase()) {
      case 'GET':
        // El body de un GET se traduce a query params (?k=v).
        final queryUri = uri.replace(queryParameters: body?.map((k, v) => MapEntry(k, v.toString())));
        return client.get(queryUri, headers: headers).timeout(_timeout);
      case 'POST':
        return client.post(uri, headers: headers, body: encodedBody).timeout(_timeout);
      case 'PUT':
        return client.put(uri, headers: headers, body: encodedBody).timeout(_timeout);
      case 'DELETE':
        return client.delete(uri, headers: headers).timeout(_timeout);
      default:
        throw UnsupportedError('Método HTTP no soportado: $method');
    }
  }

  /// Acepta cualquier 2xx. En 401 autenticado dispara el hook de sesión
  /// inválida antes de lanzar. En error lanza [ApiException] con
  /// `statusCode` + `code` del envelope del BFF.
  Future<void> _validateResponse(Response response, Uri uri, {required bool authenticated}) async {
    if (_isSuccess(response.statusCode)) return;

    if (response.statusCode == 401 && authenticated) {
      await onUnauthorized?.call();
    }

    String message = 'Ocurrió un error, contacte a soporte técnico';
    String? code;
    try {
      final body = jsonDecode(response.body);
      message = _extractMessage(body) ?? message;
      code = _extractCode(body);
    } on FormatException {
      // Cuerpo no-JSON (p. ej. página HTML de error): usa el texto si es corto.
      if (response.body.isNotEmpty && response.body.length < 70) {
        message = response.body;
      }
    }

    DebugLog.error(
      'HTTP ${response.statusCode} ${uri.path}'
      '${code != null ? ' [$code]' : ''}: $message',
    );

    throw ApiException(message, uri: uri, statusCode: response.statusCode, code: code);
  }

  /// Tolerante a las tres formas del BFF, en orden:
  /// `message:[...]` (join) → `message:"..."` → `error:"..."`.
  String? _extractMessage(dynamic body) {
    if (body is! Map) return null;
    final msg = body['message'];
    if (msg is List && msg.isNotEmpty) {
      return msg.map((e) => e.toString()).join('\n');
    }
    if (msg is String && msg.isNotEmpty) return msg;
    final err = body['error'];
    if (err is String && err.isNotEmpty) return err;
    return null;
  }

  String? _extractCode(dynamic body) => (body is Map && body['code'] is String) ? body['code'] as String : null;

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  IOClient buildClient() {
    if (!allowSelfSigned) return IOClient(HttpClient());
    final HttpClient client = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(client);
  }

  void dispose() => _client.close();
}
