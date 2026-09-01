import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/widgets/media/qr_scan_screen.dart';
import 'package:gaso_tenant_app/features/material_validation/data/material_validation_service.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/verify_folio_result.dart';

/// Flujo compartido "Dar salida" (R1/R2/R3/R4): centraliza el candado
/// `verify-folio` → ramificación por `reason` → apertura del form de salida,
/// para que la acción del AppBar, la del item y la del detalle sean idénticas.
class MaterialValidationOutFlow {
  const MaterialValidationOutFlow._();

  /// Quita el prefijo del deep link cuando el valor viene de un escaneo.
  static String normalizeFolio(String raw) =>
      raw.replaceFirst(RegExp(r'^gasosaas://mv/', caseSensitive: false), '').trim();

  /// R1/R2 — modal "Escanea o ingresa el folio de entrada".
  static Future<void> openGiveExitModal(BuildContext context) async {
    final controller = TextEditingController();
    final folio = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dar salida', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Escanea o ingresa el folio de entrada.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Folio de entrada',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Escanear'),
                    onPressed: () async {
                      final raw = await Navigator.of(
                        ctx,
                      ).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen(title: 'Escanear entrada')));
                      if (raw != null && raw.isNotEmpty) controller.text = normalizeFolio(raw);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    child: const Text('Continuar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (folio == null || folio.isEmpty) return;
    if (!context.mounted) return;
    await runVerifyAndOpenOut(context, folio);
  }

  /// R2/R3/R4 — candado + ramificación. `inHand` evita un GET extra cuando el
  /// registro IN ya está en mano (item/detalle); si es null se carga por folio.
  static Future<void> runVerifyAndOpenOut(BuildContext context, String folio, {MaterialValidation? inHand}) async {
    final nav = Navigator.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);
    final service = MaterialValidationService();
    _showLoader(context);
    try {
      final verify = await service.verifyFolioForOut(folio);
      if (!verify.success || verify.data == null) {
        rootNav.pop();
        MessengerService.error(verify.message);
        return;
      }
      final result = verify.data!;

      if (result.reason == VerifyReason.valid) {
        MaterialValidation? materialIn = inHand;
        if (materialIn == null) {
          final detail = await service.getByFolio(result.folio);
          if (!detail.success || detail.data == null) {
            rootNav.pop();
            MessengerService.error(detail.message);
            return;
          }
          materialIn = detail.data;
        }
        rootNav.pop();
        nav.pushNamed(AppRoutes.materialValidationOut, arguments: materialIn);
        return;
      }

      rootNav.pop();
      if (result.reason == VerifyReason.alreadyExtended) {
        if (!context.mounted) return;
        await _showAlreadyExtended(context, nav, result.folioSalida);
      } else {
        MessengerService.info(result.message);
      }
    } finally {
      service.dispose();
    }
  }

  static void _showLoader(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    );
  }

  static Future<void> _showAlreadyExtended(BuildContext context, NavigatorState nav, String? folioSalida) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrada ya extendida'),
        content: const Text('Esta entrada ya tiene una salida registrada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          if (folioSalida != null && folioSalida.isNotEmpty)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                nav.pushNamed(AppRoutes.materialValidationDetail, arguments: folioSalida);
              },
              child: const Text('Ver salida'),
            ),
        ],
      ),
    );
  }
}
