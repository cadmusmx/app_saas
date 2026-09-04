import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/material_logistics_service.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/verify_folio_result.dart';

/// Flujo "Entregar" (candado `verify-folio` → ramificación → form de entrega),
/// espejo del out_flow de VM. Lo dispara la acción "Entregar" del detalle.
///
/// Los avisos van por `MessengerService` (overlay global, no rutas) para no
/// apilar modales sobre pantallas que se están cerrando.
class MaterialLogisticsOutFlow {
  const MaterialLogisticsOutFlow._();

  /// Evita re-entradas (doble-tap) sin loader modal.
  static bool _busy = false;

  /// R2/R3 — candado + ramificación. `inHand` evita un GET extra cuando el
  /// registro IN ya está en mano (detalle); si es null se carga por folio.
  static Future<void> runVerifyAndOpenOut(BuildContext context, String folio, {MaterialLogistics? inHand}) async {
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
          // Siempre traemos el detalle fresco: en LM los pendientes cambian (1:N,
          // entrega parcial), así que no confiamos en un `inHand` posiblemente
          // stale para poblar el form. `inHand` solo evita el GET si es el mismo folio.
          MaterialLogistics? materialIn = (inHand != null && inHand.folio == result.folio) ? inHand : null;
          if (materialIn == null) {
            final detail = await service.getByFolio(result.folio);
            if (!detail.success || detail.data == null) {
              MessengerService.error(detail.message);
              return;
            }
            materialIn = detail.data;
          }
          nav.pushNamed(AppRoutes.materialLogisticsOut, arguments: materialIn);
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