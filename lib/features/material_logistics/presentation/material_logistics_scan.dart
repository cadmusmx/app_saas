import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/widgets/media/qr_scan_screen.dart';

/// Entrada de escaneo de LM (§3.1): abre el escáner reusable, normaliza el valor
/// crudo (deeplink `gasosaas://ml/<folio>` o folio pelón) y navega al detalle.
///
/// El folio de LM ya trae su prefijo (`LMR-` recepción / `LME-` entrega), así que
/// a diferencia de VM aquí NO se fuerza un prefijo: solo se toma el último segmento.
class MaterialLogisticsScan {
  MaterialLogisticsScan._();

  /// Extrae el folio del valor escaneado: último segmento tras `/` (quita el
  /// esquema/prefijo del deeplink). Deja el folio tal cual (con su `LMR-`/`LME-`).
  static String normalizeFolio(String raw) {
    final str = raw.trim();
    return str.substring(str.lastIndexOf('/') + 1);
  }

  /// Abre el escáner y, si hay lectura, navega al detalle por folio.
  static Future<void> scanToDetail(BuildContext context) async {
    final nav = Navigator.of(context);
    final raw = await nav.push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen(title: 'Escanear folio')));
    if (raw == null || raw.trim().isEmpty) return;
    final folio = normalizeFolio(raw);
    if (folio.isEmpty) return;
    nav.pushNamed(AppRoutes.materialLogisticsDetail, arguments: folio);
  }
}
