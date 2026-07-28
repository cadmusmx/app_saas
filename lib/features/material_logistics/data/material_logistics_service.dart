import 'dart:io';
import 'dart:convert';
 
import 'package:gaso_tenant_app/core/http/api_exception.dart';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';

/// Capa de datos de Logística de Material contra el BFF multi-tenant.
///
/// Base del contrato: `/api/warehouses/material-logistics`.
/// `Config.apiUrl` ya incluye `/api`, así que `_base` va sin él, igual que `me_service`/`material_validation_service`.
///
/// `HttpService.send` ya inyecta `x-tenant-slug`, `x-origin-id: 3` y `Bearer`, y lanza `ApiException` en no-2xx (401 → logout).
/// Aquí solo se traduce el resultado a `ServiceResponse` con el patrón de `me_service` (`on ApiException` / `on SocketException`);
/// no se arman headers a mano ni se revisa `statusCode` manualmente (a `send` solo se llega en 2xx).
///
/// Identidad del actor (`IdUsuario`/`TenantID`) sale del token: **no** se envía `idUsuario` en crear/editar;
/// el folio identifica el registro en la URL del update (`PUT /{folio}`).
/// El RBAC lo revalida el server y ya está gateado por `RbacGate`; no se duplica.
class MaterialLogisticsService extends HttpService {
  static const String _base = 'warehouses/material-logistics';

  /// POST `/search` — listado filtrado + paginado (bit R). Paginado por query, filtros por body.
  /// Respuesta `{ rows, total, pagina, limite }`; se devuelven solo las `rows` (base_list_screen infiere `hasMore` por el tamaño de página).
  ///
  /// `filters` es agnóstico: el caller decide las claves del contrato
  /// (`re`, `fechaInicio`, `fechaFin`, `idXdock`, `idCarrier`, e `idUsuario` solo como filtro opcional "mis registros"). `re` tri-estado: omitido = ambos.
  Future<ServiceResponse<List<MaterialLogistics>>> getRecords(
    Map<String, dynamic> filters, {
    int page = 1,
    int limit = 10,
    String sort = 'DESC',
  }) async {
    final safeLimit = limit.clamp(1, 100);
    try {
      final res = await send('POST', '$_base/search?pagina=$page&limite=$safeLimit&orden=$sort', body: filters);
      final body = jsonDecode(res.body);

      final rows = body is Map ? body['rows'] : body; // fallback defensivo
      if (rows is! List) {
        DebugLog.warning('search: formato inesperado -> ${res.body}');
        return ServiceResponse.error('Formato inesperado al obtener los registros.', statusCode: res.statusCode);
      }
      final data = rows.whereType<Map>().map((e) => MaterialLogistics.fromJson(e.cast<String, dynamic>())).toList();
      return ServiceResponse.ok(data, statusCode: res.statusCode);
    } on ApiException catch (e) {
      return ServiceResponse.error(
        e.message.isNotEmpty ? e.message : 'No se pudieron cargar los registros.',
        statusCode: e.statusCode,
      );
    } on SocketException {
      return ServiceResponse.error('Sin conexión con el servidor.');
    } on FormatException {
      return ServiceResponse.error('No se pudo interpretar la respuesta del servidor.');
    } catch (e) {
      DebugLog.error('getRecords $e');
      return ServiceResponse.error('Error inesperado al cargar los registros.');
    }
  }

  /// GET `/{folio}` — detalle completo (bit R).
  /// `folio` URL-encoded. 404 si no existe en el tenant.
  /// La respuesta es la cabecera completa + `documentos` + `sitios` completo (no un envelope).
  Future<ServiceResponse<MaterialLogistics?>> getByFolio(String folio) async {
    try {
      final res = await send('GET', '$_base/${Uri.encodeComponent(folio)}');
      final body = jsonDecode(res.body);
      if (body is! Map) {
        return ServiceResponse.error('Formato inesperado al obtener el registro.', statusCode: res.statusCode);
      }
      return ServiceResponse.ok(MaterialLogistics.fromJson(body.cast<String, dynamic>()), statusCode: res.statusCode);
    } on ApiException catch (e) {
      return ServiceResponse.error(
        e.message.isNotEmpty ? e.message : 'No se pudo cargar el registro.',
        statusCode: e.statusCode,
      );
    } on SocketException {
      return ServiceResponse.error('Sin conexión con el servidor.');
    } on FormatException {
      return ServiceResponse.error('No se pudo interpretar la respuesta del servidor.');
    } catch (e) {
      DebugLog.error('getByFolio $e');
      return ServiceResponse.error('Error inesperado al cargar el registro.');
    }
  }

  /// POST `/` — crear (bit W). Devuelve el `folio` generado por el server.
  /// **Sin** `idUsuario` en el body. Respuesta `{ success:true, id, folio }`.
  /// 400 validaciones / 409 folio duplicado llegan como `ApiException`.
  Future<ServiceResponse<String>> createRecord(Map<String, dynamic> payload) async {
    try {
      final res = await send('POST', _base, body: payload);
      final body = jsonDecode(res.body);
      final ok = body is Map && body['success'] == true;
      final folio = body is Map ? body['folio'] : null;
      if (!ok || folio is! String || folio.isEmpty) {
        return ServiceResponse.error(
          (body is Map ? body['message']?.toString() : null) ?? 'No se pudo crear el registro.',
          statusCode: res.statusCode,
        );
      }
      return ServiceResponse.ok(folio, statusCode: res.statusCode);
    } on ApiException catch (e) {
      return ServiceResponse.error(
        e.message.isNotEmpty ? e.message : 'No se pudo crear el registro.',
        statusCode: e.statusCode,
      );
    } on SocketException {
      return ServiceResponse.error('Sin conexión con el servidor.');
    } on FormatException {
      return ServiceResponse.error('No se pudo interpretar la respuesta del servidor.');
    } catch (e) {
      DebugLog.error('createRecord $e');
      return ServiceResponse.error('Error inesperado al crear el registro.');
    }
  }

  /// PUT `/{folio}` — editar (bit U, **solo dueño**), diff parcial.
  /// El `folio` en la URL identifica el registro (sin `idLogistica` ni `idUsuario`).
  /// `re` no se cambia.
  /// Respuesta `{ success:true }`. 404 (no existe / no-dueño) / 400 llegan como `ApiException`.
  Future<ServiceResponse<bool>> updateRecord(String folio, Map<String, dynamic> changes) async {
    try {
      final res = await send('PUT', '$_base/${Uri.encodeComponent(folio)}', body: changes);
      final body = jsonDecode(res.body);
      final ok = body is Map && body['success'] == true;
      if (!ok) {
        return ServiceResponse.error(
          (body is Map ? body['message']?.toString() : null) ?? 'No se pudo actualizar el registro.',
          statusCode: res.statusCode,
        );
      }
      return ServiceResponse.ok(true, statusCode: res.statusCode);
    } on ApiException catch (e) {
      return ServiceResponse.error(
        e.message.isNotEmpty ? e.message : 'No se pudo actualizar el registro.',
        statusCode: e.statusCode,
      );
    } on SocketException {
      return ServiceResponse.error('Sin conexión con el servidor.');
    } on FormatException {
      return ServiceResponse.error('No se pudo interpretar la respuesta del servidor.');
    } catch (e) {
      DebugLog.error('updateRecord $e');
      return ServiceResponse.error('Error inesperado al actualizar el registro.');
    }
  }
}
