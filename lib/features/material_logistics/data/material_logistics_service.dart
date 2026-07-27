import 'dart:io';
import 'dart:convert';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';

class MaterialLogisticsService extends HttpService {
  /// Listado con filtros y paginación. Cada registro trae su `Sitios` anidado.
  Future<ServiceResponse<List<MaterialLogistics>>> getRecords(
    Map<String, dynamic> formData, {
    int page = 1,
    int limit = 10,
    String sort = 'DESC',
  }) async {
    String? message;
    List<MaterialLogistics> data = [];
    try {
      final response = await send(
        'POST',
        'logistica/getRecepcionesEntregas?pagina=$page&limite=$limit&orden=$sort',
        body: formData,
      );
      final body = jsonDecode(response.body);
      if (body is List<dynamic>) {
        data = body.map((s) => MaterialLogistics.fromJson(s)).toList();
      } else {
        DebugLog.warning(response.body);
        message = 'Formato inesperado al obtener los registros';
      }
    } on HttpException catch (e) {
      message = e.message;
    } catch (e) {
      DebugLog.error('Error cargando los registros: $e');
      message = 'Error cargando los registros';
    }
    return ServiceResponse(message == null, message: message ?? 'OK', data: data);
  }

  /// Detalle por folio (cabecera + sitios → tipos/incidencias/evidencias).
  Future<ServiceResponse<MaterialLogistics?>> getByFolio(String folio) async {
    String? message;
    MaterialLogistics? data;
    try {
      final response = await send('POST', 'logistica/getRecepcionEntregaByFolio', body: {'folio': folio});
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        data = MaterialLogistics.fromJson(body);
      } else {
        DebugLog.warning(response.body);
        message = 'Formato inesperado al obtener el registro';
      }
    } on HttpException catch (e) {
      message = e.message;
    } catch (e) {
      DebugLog.error('Error cargando el registro: $e');
      message = 'Error cargando el registro';
    }
    return ServiceResponse(message == null, message: message ?? 'OK', data: data);
  }

  /// Crear (POST) o editar (PUT) una recepción/entrega.
  /// - Creación: `formData` lleva la cabecera + `sitios[]`; la respuesta trae `folio`.
  /// - Edición: `formData` lleva `idLogistica` + `sitiosDel/sitiosAdd/sitiosEdit`;
  Future<ServiceResponse<String>> recepcionEntrega(Map<String, dynamic> formData, bool re, bool isEdition) async {
    final method = isEdition ? 'PUT' : 'POST';
    String data = '';
    String? message;
    try {
      final response = await send(method, 'logistica/recepcionEntrega', body: formData);
      if (response.statusCode >= 400) {
        message = 'Error del servidor (${response.statusCode}): ${response.reasonPhrase}';
      }
      late Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        message = 'Error al interpretar la respuesta del servidor.';
      }
      if (body['success'] == true) {
        data = body['folio'] ?? '';
      } else {
        message = body['message'] ?? 'Error desconocido';
      }
    } on HttpException catch (e) {
      message = e.message;
    } catch (e) {
      DebugLog.error('Error: $e');
      message = 'Ocurrió un error inesperado';
    }
    return ServiceResponse(message == null,
        message: message ?? '${re ? 'Recepción' : 'Entrega'} ${isEdition ? 'modificada' : 'creada'} con éxito.', data: data);
  }

  Future<ServiceResponse<List<OptionSL>>> getXdocks() => _getCatalogList('logistica/rmXdocks', 'los XDOCKs');

  Future<ServiceResponse<List<OptionSL>>> getMaterialTypes() =>
      _getCatalogList('logistica/rmTiposMaterial', 'los tipos de material');

  Future<ServiceResponse<List<OptionSL>>> getIncidenceTypes() =>
      _getCatalogList('logistica/rmTiposIncidencia', 'los tipos de incidencia');

  Future<ServiceResponse<List<OptionSL>>> getEvidenceTypes() =>
      _getCatalogList('logistica/rmTiposEvidencia', 'los tipos de evidencia');

  Future<ServiceResponse<List<OptionSL>>> getCarriers() => _getCatalogList('logistica/rmCarriers', 'los carriers');

  Future<ServiceResponse<List<OptionSL>>> _getCatalogList(String endpoint, String listName,
      {String method = 'GET', String kText = 'Nombre', String kValue = 'Id'}) async {
    String? message;
    List<OptionSL> data = [];
    try {
      final response = await send(method, endpoint);
      final responseBody = jsonDecode(response.body);
      if (responseBody is List<dynamic>) {
        data = responseBody.map((obj) => OptionSL(text: obj[kText].toString(), value: obj[kValue].toString())).toList();
      } else {
        DebugLog.warning(response.body);
        message = 'Formato inesperado al obtener $listName';
      }
    } on HttpException catch (e) {
      message = e.message;
    } catch (e) {
      DebugLog.error('Error cargando $listName: $e');
      message = 'Error cargando $listName';
    }
    return ServiceResponse(message == null, message: message ?? 'OK', data: data);
  }
}