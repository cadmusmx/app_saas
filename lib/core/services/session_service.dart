import 'dart:convert';
import 'dart:io';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';

class SessionService extends HttpService { 
  /// TODO: guardar y enviar el token de Firebase
  Future<ServiceResponse<String>> updateTokenFirebase(String token) async {
    String? data;
    try {
      final response = await send(
        'POST',
        'updateTokenFirebase', // USAR ENDPOINT REAL
        body: {'tokenFirebase': token},
      );
      try {
        final responseBody = jsonDecode(response.body);
        if (!(responseBody is Map && responseBody['ok'])) {
          data = responseBody['message'];
        }
      } on FormatException {
        data = 'Error al interpretar la respuesta del servidor.';
      }
    } on SocketException {
      data = 'Sin conexión con el servidor.';
    } on HttpException catch (e) {
      data = e.message;
    } catch (e) {
      DebugLog.warning('updateTokenFirebase $e');
      data = 'Error inesperado, intente de nuevo mas tarde.';
    }
    return ServiceResponse(success: data == null, data: data ?? 'OK');
  }
}