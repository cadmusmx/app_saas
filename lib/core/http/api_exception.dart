import 'dart:io';

/// Excepción de API con el `statusCode` y el `code` del envelope del BFF
/// (`{ ok:false, code, message:[] }`).
///
/// Extiende [HttpException] de `dart:io` para ser retrocompatible: todo
/// `catch on HttpException` existente la sigue atrapando, y el código nuevo
/// puede hacer `catch on ApiException` para leer `statusCode`/`code` y decidir
/// el flujo (p. ej. `MFA_EXPIRED` → reiniciar el reto).
class ApiException extends HttpException {
  /// HTTP status (401, 403, 404, 500, 502, …). Null en errores de red/timeout.
  final int? statusCode;

  /// `code` del envelope normalizado del BFF (`TENANT_SUSPENDED`,
  /// `INVALID_CREDENTIALS`, `MFA_REQUIRED`, `MFA_INVALID`, `MFA_EXPIRED`, …).
  final String? code;

  const ApiException(super.message, {super.uri, this.statusCode, this.code});

  @override
  String toString() => 'ApiException($statusCode${code != null ? ', $code' : ''}): $message';
}