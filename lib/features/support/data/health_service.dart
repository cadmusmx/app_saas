import 'dart:io';
import 'dart:convert';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';

class HealthService extends HttpService {
  Future<ServiceResponse<Map<String, dynamic>>> check() async {
    try {
      final response = await send('GET', '/health');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ServiceResponse.ok(data, statusCode: response.statusCode);
    } on HttpException catch (e) {
      return ServiceResponse.error(e.message);
    } catch (e) {
      return ServiceResponse.error('Error inesperado: $e');
    }
  }
}
