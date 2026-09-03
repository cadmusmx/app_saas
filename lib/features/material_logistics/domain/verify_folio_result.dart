// ignore_for_file: constant_identifier_names

/// Resultado tipado de `GET /verify-folio` (contrato §4.1).
/// El endpoint responde **200 siempre**; el veredicto viaja en `reason`, no en el
/// status. `idIn` es informativo (la app rutea por `folio`).
///
/// A diferencia de VM (1:1, `folioSalida` en `ALREADY_EXTENDED`), LM es 1:N: en
/// `ALL_DELIVERED` **no** hay un folio único de salida — la app va al detalle de la
/// recepción y usa su `entregas[]`.
enum VerifyReason { valid, allDelivered, notFound, notIn, unknown }

class VerifyFolioResult {
  final VerifyReason reason;
  final String folio; // folio ya normalizado por el server (LMR-…)
  final int? idIn; // informativo (presente en VALID)

  const VerifyFolioResult({required this.reason, required this.folio, this.idIn});

  bool get isValid => reason == VerifyReason.valid;

  /// Mensaje en español para `reason != VALID`. VALID no muestra mensaje: abre el
  /// form de entrega. Vocabulario de usuario (recepción/entrega), nunca dev.
  String get message {
    switch (reason) {
      case VerifyReason.allDelivered:
        return 'Esta recepción ya se entregó por completo.';
      case VerifyReason.notFound:
        return 'No se encontró el folio en esta empresa.';
      case VerifyReason.notIn:
        return 'El folio no corresponde a una recepción válida.';
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
      idIn: json['idIn'] is int ? json['idIn'] as int : int.tryParse('${json['idIn']}'),
    );
  }

  static VerifyReason _parseReason(dynamic raw) {
    switch (raw?.toString().toUpperCase()) {
      case 'VALID':
        return VerifyReason.valid;
      case 'ALL_DELIVERED':
        return VerifyReason.allDelivered;
      case 'NOT_FOUND':
        return VerifyReason.notFound;
      case 'NOT_IN':
        return VerifyReason.notIn;
      default:
        return VerifyReason.unknown;
    }
  }
}