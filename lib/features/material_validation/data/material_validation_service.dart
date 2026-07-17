import 'dart:convert';
import 'dart:io';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';

class MaterialValidationService extends HttpService {
  /// Obtiene los registros de vme del usuario
  Future<ServiceResponse<List<MaterialValidation>>> getRecords(
    Map<String, dynamic> formData, {
    int page = 1,
    int limit = 10,
    String sort = 'DESC',
  }) async {
    String? message;
    List<MaterialValidation> data = [];
    try {
      final response = await send(
        'POST',
        'material/getMaterialEntradaSalida?pagina=$page&limite=$limit&orden=$sort',
        body: formData,
      );
      final body = jsonDecode(response.body);
      if (body is List<dynamic>) {
        data = body.map((s) => MaterialValidation.fromJson(s)).toList();
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

  Future<ServiceResponse<MaterialValidation?>> getByFolio(String folio) async {
    String? message;
    MaterialValidation? data;
    try {
      final response = await send('POST', 'material/getByFolio', body: {'folio': folio});
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        data = MaterialValidation.fromJson(body);
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

  /// Crear o editar una entrada/salida
  Future<ServiceResponse<String>> materialValidation(Map<String, dynamic> formData, bool es, bool isEdition) async {
    final method = isEdition ? 'PUT' : 'POST';
    String? data;
    try {
      if (!isEdition) {
        formData['es'] = es;
      }
      final response = await send(method, 'material/materialEntradaSalida', body: formData);
      if (response.statusCode >= 400) {
        data = 'Error del servidor (${response.statusCode}): ${response.reasonPhrase}';
      }
      late Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        data = 'Error al interpretar la respuesta del servidor.';
      }
      if (isEdition && !(body['success'] ?? false)) {
        data = 'La ${es ? 'entrada' : 'salida'} ya ha sido revisada.';
      }
    } on SocketException {
      data = 'Sin conexión con el servidor.';
    } on HttpException catch (e) {
      data = e.message;
    } catch (e) {
      DebugLog.error('$e');
      data = 'Error inesperado al enviar la ${es ? 'entrada' : 'salida'}.';
    }
    return ServiceResponse(
      data == null,
      data: data ?? '${es ? 'Entrada' : 'Salida'} de material ${isEdition ? 'actualizada' : 'creada'} exitosamente.',
    );
  }

  Future<ServiceResponse<bool>> verifyLinkedFolio(String folio) async {
    String? message;
    bool vinculado = true; // default seguro
    try {
      final response = await send('POST', 'material/verificarFolioVinculado', body: {'folio': folio});
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['success'] == true) {
        vinculado = body['vinculado'] ?? true;
      } else {
        message = body['message'] ?? 'Error al verificar el folio';
      }
    } on HttpException catch (e) {
      message = e.message;
    } catch (e) {
      DebugLog.error('Error verificando folio: $e');
      message = 'Error al verificar el folio';
    }
    return ServiceResponse(message == null, message: message ?? 'OK', data: vinculado);
  }

  Future<ServiceResponse<List<OptionSL>>> getWarehouses() async {
    return _getCatalogList('material/almacenes', 'los almacenes', kText: 'Nombre');
  }

  Future<ServiceResponse<List<OptionSL>>> getProjects() async {
    return _getCatalogList('material/vmProyectos', 'los proyectos', kText: 'Proyecto');
  }

  Future<ServiceResponse<List<OptionSL>>> getReasons() async {
    return _getCatalogList('material/vmMotivos', 'los motivos', kText: 'Motivo');
  }

  Future<ServiceResponse<List<OptionSL>>> getPhysicalStatus() async {
    return _getCatalogList('material/vmEstadosF', 'los estados físicos', kText: 'Estado', kValue: 'Clave');
  }

  Future<ServiceResponse<List<OptionSL>>> getMaterialTypes() async {
    return _getCatalogList('material/vmTiposMaterial', 'los tipos', kText: 'Tipo');
  }

  Future<ServiceResponse<List<OptionSL>>> getCarriers() async {
    return _getCatalogList('material/vmCarrier', 'los carriers', kText: 'Carrier');
  }

  /// Obtiene el catalogo desde API
  Future<ServiceResponse<List<OptionSL>>> _getCatalogList(String endpoint, String listName,
      {String method = 'GET', String kText = 'Text', String kValue = 'Id'}) async {
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
