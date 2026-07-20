import 'dart:convert';
import 'dart:io';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/features/profile/domain/profile.dart';

class ProfileService extends HttpService {
  /// Método genérico para actualizar información del usuario.
  Future<ServiceResponse<String>> _updateUserData(String endpoint, Map<String, dynamic> formData,
      {String? errorMessage}) async {
    String? data;
    try {
      final response = await send('POST', endpoint, body: formData);
      if (response.statusCode != 200) {
        data = 'Error del servidor (${response.statusCode}): ${response.reasonPhrase}';
      }
    } on SocketException {
      data = 'Sin conexión con el servidor.';
    } on HttpException catch (e) {
      data = e.message;
    } catch (_) {
      data = errorMessage ?? 'Error inesperado al actualizar los datos del usuario.';
    }
    return ServiceResponse(data == null, data: data ?? 'OK');
  }

  Future<ServiceResponse<String>> updateUser(Map<String, dynamic> formData) =>
      _updateUserData('apialmacen/updateUsuarioMovil', formData,
          errorMessage: 'Error inesperado al actualizar los datos de usuario.');

  Future<ServiceResponse<String>> updateUserName(Map<String, dynamic> formData) =>
      _updateUserData('apialmacen/updateNombreUsuario', formData,
          errorMessage: 'Error inesperado al actualizar el nombre de usuario.');

  Future<ServiceResponse<String>> updatePassword(Map<String, dynamic> formData) =>
      _updateUserData('apialmacen/updatePassword', formData,
          errorMessage: 'Error inesperado al actualizar la contraseña.');

  Future<ServiceResponse<String>> updateContact(Map<String, dynamic> formData) =>
      _updateUserData('apialmacen/updateUsuarioContact', formData,
          errorMessage: 'Error inesperado al actualizar el contacto.');

  Future<ServiceResponse<String>> addFiles(Map<String, dynamic> formData) =>
      _updateUserData('apialmacen/addFiles', formData, errorMessage: 'Error inesperado al agregar los archivos');

  /// Obtiene los documentos del Usuario
  Future<ServiceResponse<UserDocuments?>> getDocuments(int idUsuario) async {
    UserDocuments? data;
    String? message;
    try {
      final response = await send('GET', 'apialmacen/getDocumentos', body: {'IdUsuario': idUsuario});
      final body = jsonDecode(response.body);
      final result = body is Map ? body['resultado']?.toString() ?? '' : '';
      if (result.isNotEmpty) {
        final documents = jsonDecode(result);
        final json = documents[0];
        data = UserDocuments.fromJson(json);
      } else {
        message = 'No se encontraron documentos registrados';
      }
    } on HttpException catch (e) {
      message = e.message;
    } catch (e) {
      DebugLog.warning('$e');
      message = 'Ocurrió un error al obtener los documentos del usuario';
    }
    return ServiceResponse(message == null, message: message ?? 'OK', data: data);
  }
}
