import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/widgets/media/folio_entry_sheet.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/material_logistics_service.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/verify_folio_result.dart';

/// Flujo "Entregar" (candado `verify-folio` → ramificación → form de entrega),
/// espejo del out_flow de VM. Lo disparan: la acción "Entregar" del detalle, el
/// item de la lista, y el modal del AppBar ([openGiveExitModal], útil para folios
/// **legacy** sin QR: se teclean).
///
/// Los avisos van por `MessengerService` (overlay global, no rutas) para no
/// apilar modales sobre pantallas que se están cerrando.
class MaterialLogisticsOutFlow {
  const MaterialLogisticsOutFlow._();

  /// Evita re-entradas (doble-tap) sin loader modal.
  static bool _busy = false;

  /// Entrada por AppBar: modal reusable "escanea o ingresa el folio de recepción"
  /// → ramificación. El input de texto es la vía para los registros legacy (sin QR).
  static Future<void> openGiveExitModal(BuildContext context) async {
    final folio = await showFolioEntrySheet(
      context,
      title: 'Entregar',
      subtitle: 'Escanea o ingresa el folio de la recepción.',
      inputLabel: 'Folio de recepción',
      scanTitle: 'Escanear recepción',
    );
    if (folio == null || folio.isEmpty) return;
    if (!context.mounted) return;
    await runVerifyAndOpenOut(context, folio);
  }

  /// R2/R3 — candado + ramificación. En VALID **siempre** trae el detalle fresco
  /// (`getByFolio`): en LM los pendientes cambian (1:N / entrega parcial) y
  /// cualquier registro en mano —lista o detalle— puede estar stale; el 409 al
  /// enviar es el backstop. Sin `inHand`: mismo comportamiento desde todo origen.
  static Future<void> runVerifyAndOpenOut(BuildContext context, String folio) async {
    // Feedback inmediato para un folio de ENTREGA (LME-): no es una recepción, no
    // se puede entregar desde él. Evita un round-trip que devolvería NOT_IN.
    if (folio.trim().toUpperCase().startsWith('LME')) {
      MessengerService.info('Ese folio es de una entrega, no de una recepción.');
      return;
    }
    if (_busy) return;
    _busy = true;
    // Navigator capturado ANTES del primer await: nunca usamos `context` tras un
    // await → sin riesgo de use_build_context_synchronously.
    final nav = Navigator.of(context);
    final service = MaterialLogisticsService();
    try {
      final verify = await service.verifyFolioForOut(folio);
      if (!verify.success || verify.data == null) {
        MessengerService.error(verify.message);
        return;
      }
      final result = verify.data!;

      switch (result.reason) {
        case VerifyReason.valid:
          final detail = await service.getByFolio(result.folio);
          if (!detail.success || detail.data == null) {
            MessengerService.error(detail.message);
            return;
          }
          nav.pushNamed(AppRoutes.materialLogisticsOut, arguments: detail.data);
          return;

        case VerifyReason.allDelivered:
          // 1:N: no hay folio único de entrega → al detalle de la recepción, que
          // ofrece "Ver entregas" sobre su `entregas[]`.
          MessengerService.actionSnackBar(
            result.message,
            () => nav.pushNamed(AppRoutes.materialLogisticsDetail, arguments: result.folio),
            'Ver entregas',
          );
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