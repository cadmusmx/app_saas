import 'package:gaso_tenant_app/core/config/env.dart';

class Config {
  Config._();

  /// Entorno lógico de la app: dev | qa | prod.
  static const AppEnv appEnv = AppEnv.qa;

  /// URL base de la API (leída desde .env via Env.apiUrl).
  static String apiUrl = 'http://192.168.0.14:3000/api/'; // La API cambia en función del tenant [PENDIENTE: revisar cuando cada tenant tenga su url en producción]

  /// Carpeta S3 por entorno (`Qa`/`Pr`). Se antepone a TODA llave de objeto:
  /// la escritura la resuelve `S3Service`; la lectura la antepone `s3Url`.
  static String get s3Folder => appEnv == AppEnv.prod ? 'Pr' : 'Qa';

  /// Base pública de S3 (lectura). Incluye el folder de entorno y toma la región
  /// de `Env.s3Region` —la misma que usa `S3Service` al escribir— para que la URL
  /// de lectura apunte exactamente a donde quedó el objeto.
  static String get s3Url => 'https://${Env.s3Bucket}.s3.${Env.s3Region}.amazonaws.com/$s3Folder/';

  /// Header de tenant que espera el BFF.
  static const String tenantHeaderName = 'x-tenant-slug';

  // FCM habilitar solo en prod.
  static const bool fireBaseToken = false;
}

enum AppEnv { dev, qa, prod }