import 'dart:convert';
import 'dart:io';

import 'package:gaso_tenant_app/core/http/api_exception.dart';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';

/// Capa de datos de Validación de Material contra el BFF multi-tenant.
///
/// Base del contrato: `/api/warehouses/material-validation`.
/// `Config.apiUrl` ya incluye `/api`, así que `_base` va sin él y con slash inicial, igual que
/// `me_service` (`/me`).
///
/// `HttpService.send` ya inyecta `x-tenant-slug`, `x-origin-id: 3` y `Bearer`,
/// y lanza `ApiException` en no-2xx (401 → logout). Aquí solo se traduce el
/// resultado a `ServiceResponse` con el patrón de `me_service`
/// (`on ApiException` / `on SocketException`); no se arman headers a mano ni se
/// revisa `statusCode` manualmente (a `send` solo se llega en 2xx).
///
/// Identidad del actor (`IdUsuario`/`TenantID`) sale del token: **no** se envía
/// `idUsuario` en crear/editar ni `idMaterial` en editar (el folio va en la URL).
/// El RBAC lo revalida el server y ya está gateado por `RbacGate`; no se duplica.
class MaterialValidationService extends HttpService {
  static const String _base = 'warehouses/material-validation';

  /// POST `/search` — listado filtrado + paginado (bit R). Paginado por query,
  /// filtros por body. La respuesta es `{ rows, total, pagina, limite }`; se
  /// devuelven solo las `rows` (base_list_screen infiere `hasMore` por el tamaño
  /// de la página, no consume `total`).
  ///
  /// `filters` es agnóstico: el caller decide las claves del contrato
  /// (`es`, `proyecto`, `tipoMaterial`, `almacen`, `carrier`, `fechaInicio`,
  /// `fechaFin`, e `idUsuario` **solo** como filtro opcional "mis registros").
  Future<ServiceResponse<List<MaterialValidation>>> getRecords(
    Map<String, dynamic> filters, {
    int page = 1,
    int limit = 10,
    String sort = 'DESC',
  }) async {
    final safeLimit = limit.clamp(1, 100);
    try {
      final res = await send(
        'POST',
        '$_base/search?pagina=$page&limite=$safeLimit&orden=$sort',
        body: filters,
      );
      final body = jsonDecode(res.body);
      final rows = body is Map ? body['rows'] : body; // fallback defensivo si llegara desnudo
      if (rows is! List) {
        DebugLog.warning('search: formato inesperado -> ${res.body}');
        return ServiceResponse.error('Formato inesperado al obtener los registros.', statusCode: res.statusCode);
      }
      final data = rows
          .whereType<Map>()
          .map((e) => MaterialValidation.fromJson(e.cast<String, dynamic>()))
          .toList();
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

  /// GET `/{folio}` — detalle (bit R). `folio` URL-encoded. 404 si no existe en
  /// el tenant. La respuesta es el objeto (cabecera completa), no un envelope.
  Future<ServiceResponse<MaterialValidation?>> getByFolio(String folio) async {
    try {
      final res = await send('GET', '$_base/${Uri.encodeComponent(folio)}');
      final body = jsonDecode(res.body);
      if (body is! Map) {
        return ServiceResponse.error('Formato inesperado al obtener el registro.', statusCode: res.statusCode);
      }
      return ServiceResponse.ok(
        MaterialValidation.fromJson(body.cast<String, dynamic>()),
        statusCode: res.statusCode,
      );
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

  /// POST `/` — crear (bit W). Devuelve el `id` nuevo. **Sin** `idUsuario` en el
  /// body. La respuesta es `{ success:true, id:123 }`. 409 folio duplicado /
  /// 400 validaciones llegan como `ApiException`.
  Future<ServiceResponse<int>> createRecord(Map<String, dynamic> payload) async {
    try {
      final res = await send('POST', _base, body: payload);
      final body = jsonDecode(res.body);
      final ok = body is Map && body['success'] == true;
      final id = body is Map ? body['id'] : null;
      if (!ok || id is! int) {
        return ServiceResponse.error(
          (body is Map ? body['message']?.toString() : null) ?? 'No se pudo crear el registro.',
          statusCode: res.statusCode,
        );
      }
      return ServiceResponse.ok(id, statusCode: res.statusCode);
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

  /// PUT `/{folio}` — editar (bit U), **diff parcial**. El `folio` en la URL
  /// identifica el registro (sin `idMaterial` ni `idUsuario`). El server decide
  /// el modo por pertenencia (dueño = completo; no-dueño con U = subset web).
  /// Requiere `Status == 0`. 409 no editable / 404 no existe / 400 no-dueño sin
  /// campos web llegan como `ApiException`.
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

  /// GET `/linked?folio=` — ¿folio vinculado? (bit R). Respuesta
  /// `{ success:true, vinculado:false }`. El folio va en la query (no como body,
  /// para no colisionar con la traducción GET-body→query de `HttpService`).
  /// Fail-closed a cargo del caller (deja `vinculado = true` ante error).
  Future<ServiceResponse<bool>> verifyLinkedFolio(String folio) async {
    try {
      final res = await send('GET', '$_base/linked?folio=${Uri.encodeComponent(folio)}');
      final body = jsonDecode(res.body);
      if (body is! Map || body['success'] != true) {
        return ServiceResponse.error(
          (body is Map ? body['message']?.toString() : null) ?? 'No se pudo verificar el folio.',
          statusCode: res.statusCode,
        );
      }
      return ServiceResponse.ok(body['vinculado'] == true, statusCode: res.statusCode);
    } on ApiException catch (e) {
      return ServiceResponse.error(
        e.message.isNotEmpty ? e.message : 'No se pudo verificar el folio.',
        statusCode: e.statusCode,
      );
    } on SocketException {
      return ServiceResponse.error('Sin conexión con el servidor.');
    } on FormatException {
      return ServiceResponse.error('No se pudo interpretar la respuesta del servidor.');
    } catch (e) {
      DebugLog.error('verifyLinkedFolio $e');
      return ServiceResponse.error('Error al verificar el folio.');
    }
  }
}
