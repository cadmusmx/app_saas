import 'dart:convert';
import 'dart:io';

import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:gaso_tenant_app/core/http/api_exception.dart';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';

/// Formaliza el MeService (dev-only en S2, TC-15 / interceptor 401).
/// `getMe()` consume `GET /api/me` y devuelve la `SessionUser` ya mapeada.
///
/// El saneo fail-closed de cada `view.mask` (y su tripwire) ocurre en `SessionUser.fromMe` — punto único de mapeo.
/// Un 401 aquí ya fue interceptado por `HttpService` (dispara `onUnauthorized` → logout) antes de llegar al catch;
/// aquí solo se traduce el error a `ServiceResponse`.
class MeService extends HttpService {
  /// GET /api/me → SessionUser. Requiere sesión (Bearer) + tenant en headers,
  /// ambos ya cableados por `HttpService.send` (autenticado).
  Future<ServiceResponse<SessionUser?>> getMe() async {
    try {
      final res = await send('GET', 'me');

      final body = jsonDecode(res.body);
      if (body is! Map) {
        return ServiceResponse.error('Respuesta inválida de /api/me.', statusCode: res.statusCode);
      }

      final session = SessionUser.fromMe(body.cast<String, dynamic>());
      return ServiceResponse.ok(session, statusCode: res.statusCode);
    } on ApiException catch (e) {
      // 401 → HttpService ya invalidó la sesión. 403 TENANT_SUSPENDED, etc.
      return ServiceResponse.error(
        e.message.isNotEmpty ? e.message : 'No se pudo cargar la sesión.',
        statusCode: e.statusCode,
      );
    } on SocketException {
      return ServiceResponse.error('Sin conexión con el servidor.');
    } on FormatException {
      return ServiceResponse.error('No se pudo interpretar la respuesta del servidor.');
    } catch (e) {
      DebugLog.error('getMe $e');
      return ServiceResponse.error('Error inesperado al cargar la sesión.');
    }
  }
}
