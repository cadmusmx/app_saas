import 'dart:io';
import 'dart:convert';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/tenant/tenant.dart';

class TenantService extends HttpService {
  /// Resuelve un slug/dominio contra la API Next.js. Sin caché.
  ///
  /// Endpoint: GET /internal/resolve-tenant?domain={slug}
  /// Respuesta: { tenant: { TenantID, CompanyName, isActive, Dominio } } | { tenant: null }
  ///
  /// - activo     → ServiceResponse.ok(tenant)
  /// - suspendido → ServiceResponse.error(..., statusCode: 403)
  /// - no existe  → ServiceResponse.error(..., statusCode: 404)
  /// - red/otro   → ServiceResponse.error(...)
  Future<ServiceResponse<Tenant?>> resolve(String slug) async {
    try {
      final res = await sendNoTenant('GET', 'internal/resolve-tenant', body: {'domain': slug});
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      final raw = body['tenant'];
      if (raw == null) {
        return ServiceResponse.error('Empresa no encontrada. Verifica el nombre.', statusCode: 404);
      }

      final tenant = Tenant.fromBff(raw as Map<String, dynamic>, fallbackSlug: slug);

      if (!tenant.isActive) {
        return ServiceResponse.error('Esta empresa está suspendida. Contacta a soporte.', statusCode: 403);
      }

      return ServiceResponse.ok(tenant, statusCode: res.statusCode);
    } on HttpException catch (e) {
      return ServiceResponse.error(
        e.message.isNotEmpty ? e.message : 'Empresa no encontrada. Verifica el nombre.',
        statusCode: 404,
      );
    } on SocketException {
      return ServiceResponse.error('Sin conexión. Verifica tu internet.');
    } catch (e) {
      DebugLog.error('resolve $e');
      return ServiceResponse.error('Ocurrió un error inesperado.');
    }
  }
}
