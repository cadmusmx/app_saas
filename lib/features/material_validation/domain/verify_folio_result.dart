// ignore_for_file: constant_identifier_names

/// Resultado tipado de `GET /verify-folio` (contrato §4.1).
/// El endpoint responde **200 siempre**; el veredicto viaja en `reason`, no en
/// el status. `folioSalida` solo llega en `ALREADY_EXTENDED`.
enum VerifyReason { valid, alreadyExtended, notFound, notIn, unknown }

class VerifyFolioResult {
  final VerifyReason reason;
  final String folio; // folio ya normalizado por el server (VME-…)
  final String? folioSalida; // presente solo en ALREADY_EXTENDED

  const VerifyFolioResult({required this.reason, required this.folio, this.folioSalida});

  bool get isValid => reason == VerifyReason.valid;

  /// Mensaje en español para `reason != VALID`. VALID no muestra mensaje: abre
  /// el form de salida. Vocabulario de usuario (entrada/salida), nunca dev.
  String get message {
    switch (reason) {
      case VerifyReason.alreadyExtended:
        return 'Esta entrada ya tiene salida.';
      case VerifyReason.notFound:
        return 'No se encontró el folio en esta empresa.';
      case VerifyReason.notIn:
        return 'El folio no corresponde a una entrada válida.';
      case VerifyReason.valid:
        return '';
      case VerifyReason.unknown:
        return 'No se pudo verificar el folio.';
    }
  }

  factory VerifyFolioResult.fromJson(Map<String, dynamic> json) {
    return VerifyFolioResult(
      reason: _parseReason(json['reason']),
      folio: (json['folio'] as String?) ?? '',
      folioSalida: json['folioSalida'] as String?,
    );
  }

  static VerifyReason _parseReason(dynamic raw) {
    switch (raw?.toString().toUpperCase()) {
      case 'VALID':
        return VerifyReason.valid;
      case 'ALREADY_EXTENDED':
        return VerifyReason.alreadyExtended;
      case 'NOT_FOUND':
        return VerifyReason.notFound;
      case 'NOT_IN':
        return VerifyReason.notIn;
      default:
        return VerifyReason.unknown;
    }
  }
}
