import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/widgets/media/folio_entry_sheet.dart';
import 'package:gaso_tenant_app/features/material_validation/data/material_validation_service.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/verify_folio_result.dart';

/// Flujo compartido "Dar salida" (R1/R2/R3/R4): centraliza el candado
/// `verify-folio` → ramificación por `reason` → apertura del form de salida,
/// para que la acción del AppBar, la del item y la del detalle sean idénticas.
///
/// Los avisos van por `MessengerService` (overlay global, no rutas): así no se
/// apilan modales sobre el bottom sheet que se está cerrando, lo que disparaba
/// `InheritedElement.debugDeactivated() → assert(_dependents.isEmpty)`.
class MaterialValidationOutFlow {
  const MaterialValidationOutFlow._();

  /// Evita re-entradas (doble-tap) sin necesidad de un loader modal.
  static bool _busy = false;

  // Normaliza el folio IN. Acepta cualquier origen:
  // deeplink escaneado (gasosaas://mv/VME-…), folio escaneado como texto, o tecleado (con/sin VME-).
  static String normalizeFolio(String raw) {
    final str = raw.trim();
    final txt = str.substring(str.lastIndexOf('/') + 1, str.length);

    return txt.startsWith('VME') ? txt : 'VME-$txt';
  }

  /// R1/R2 — modal "Escanea o ingresa el folio de entrada".
   static Future<void> openGiveExitModal(BuildContext context) async {
    final raw = await showFolioEntrySheet(
      context,
      title: 'Dar salida',
      subtitle: 'Escanea o ingresa el folio de entrada.',
      inputLabel: 'Folio de entrada',
      scanTitle: 'Escanear entrada',
    );
    if (raw == null || raw.isEmpty) return;
    if (!context.mounted) return;
    await runVerifyAndOpenOut(context, normalizeFolio(raw));
  }

  /// R2/R3/R4 — candado + ramificación. `inHand` evita un GET extra cuando el
  /// registro IN ya está en mano (item/detalle); si es null se carga por folio.
  static Future<void> runVerifyAndOpenOut(BuildContext context, String folio, {MaterialValidation? inHand}) async {
    if (_busy) return;
    _busy = true;
    // Capturamos el navigator ANTES del primer await: nunca usamos `context`
    // tras un await, por lo que no hay riesgo de use_build_context_synchronously.
    final nav = Navigator.of(context);
    final service = MaterialValidationService();
    try {
      final verify = await service.verifyFolioForOut(folio);
      if (!verify.success || verify.data == null) {
        MessengerService.error(verify.message);
        return;
      }
      final result = verify.data!;

      switch (result.reason) {
        case VerifyReason.valid:
          MaterialValidation? materialIn = inHand;
          if (materialIn == null) {
            final detail = await service.getByFolio(result.folio);
            if (!detail.success || detail.data == null) {
              MessengerService.error(detail.message);
              return;
            }
            materialIn = detail.data;
          }
          nav.pushNamed(AppRoutes.materialValidationOut, arguments: materialIn);
          return;

        case VerifyReason.alreadyExtended:
          final folioSalida = result.folioSalida;
          if (folioSalida != null && folioSalida.isNotEmpty) {
            MessengerService.actionSnackBar(
              'Esta entrada ya tiene salida.',
              () => nav.pushNamed(AppRoutes.materialValidationDetail, arguments: folioSalida),
              'Ver salida',
            );
          } else {
            MessengerService.info('Esta entrada ya tiene salida.');
          }
          return;

        case VerifyReason.notFound:
        case VerifyReason.notIn:
        case VerifyReason.unknown:
          MessengerService.info(result.message);
          return;
      }
    } finally {
      service.dispose();
      _busy = false;
    }
  }
}
