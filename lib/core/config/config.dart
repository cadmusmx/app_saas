import 'package:gaso_tenant_app/core/config/env.dart';

class Config {
  Config._();

  /// Entorno lógico de la app: dev | qa | prod.
  static const AppEnv appEnv = AppEnv.dev;

  /// URL base de la API (no prod), En producción se genera en base al slug-tenant del usuario en sesión
  static const String apiUrl = 'http://192.168.0.13:3000/api/';

  /// Carpeta S3 por entorno (`Qa`/`Pr`).
  /// Se hornea en la llave completa que guarda la app; `S3Service._resolveKey` la respeta de forma idempotente al escribir.
  static String get s3Folder => appEnv == AppEnv.prod ? 'Pr' : 'Qa';

  /// Raíz pública del bucket (lectura).
  /// NO incluye el entorno: este ya viene dentro de la llave completa almacenada (`Qa/…`|`Pr/…`).
  /// Región desde `Env.s3Region`.
  static String get s3Url => 'https://${Env.s3Bucket}.s3.${Env.s3Region}.amazonaws.com/';

  /// Header de tenant que espera el BFF.
  static const String tenantHeaderName = 'x-tenant-slug';

  // FCM habilitar solo en prod.
  static const bool fireBaseToken = false;
}

enum AppEnv { dev, qa, prod }