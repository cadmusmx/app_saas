import 'dart:io';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';

class ProfileService extends HttpService {
  
  @Deprecated('NO MIGRADO')
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

  @Deprecated('NO MIGRADO')
  Future<ServiceResponse<String>> updateUser(Map<String, dynamic> formData) =>
      _updateUserData('apialmacen/updateUsuarioMovil', formData,
          errorMessage: 'Error inesperado al actualizar los datos de usuario.');

  @Deprecated('NO MIGRADO')
  Future<ServiceResponse<String>> updateUserName(Map<String, dynamic> formData) =>
      _updateUserData('apialmacen/updateNombreUsuario', formData,
          errorMessage: 'Error inesperado al actualizar el nombre de usuario.');

  @Deprecated('NO MIGRADO')
  Future<ServiceResponse<String>> updatePassword(Map<String, dynamic> formData) =>
      _updateUserData('apialmacen/updatePassword', formData,
          errorMessage: 'Error inesperado al actualizar la contraseña.');
  
  @Deprecated('NO MIGRADO')
  Future<ServiceResponse<String>> updateProfilePhoto(Map<String, dynamic> formData) =>
      _updateUserData('apialmacen/updatePassword', formData,
          errorMessage: 'Error inesperado al actualizar la contraseña.');
}
