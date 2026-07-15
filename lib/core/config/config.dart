import 'package:gaso_tenant_app/core/config/env.dart';

class Config {
  Config._();

  /// Entorno lógico de la app: dev | qa | prod.
  static const AppEnv appEnv = AppEnv.dev;

  /// URL base de la API (leída desde .env via Env.apiUrl).
  static String get apiUrl => Env.apiUrl;

  /// Carpeta S3 depende del entorno
  static String get _s3Folder => appEnv == AppEnv.prod ? 'Pr' : 'Qa';

  /// URL S3
  static String get s3Url => 'https://${Env.s3Bucket}.s3.us-east-1.amazonaws.com/$_s3Folder/';

  /// Header de tenant que espera el BFF.
  static const String tenantHeaderName = 'x-tenant-slug';

  // FCM habilitar solo en prod.
  static const bool fireBaseToken = false;
}

enum AppEnv { dev, qa, prod }