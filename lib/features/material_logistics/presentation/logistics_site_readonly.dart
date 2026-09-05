import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/widgets/media/visual_dialogs.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';

/// Render **read-only** del material de un sitio (tipos, incidencias, evidencias,
/// tarimas, faltantes). Se comparte entre el detalle (scan→detalle) y el form de
/// entrega (donde el material del IN se muestra read-only, §3.3.1). No pinta el
/// estado de entrega (`entregado`/`folioEntrega`) ni el selector: eso lo envuelve
/// el caller (chip en el detalle, checkbox en el form).
///
/// Solo tiene sentido con datos de `/{folio}` (arreglos completos); desde `/search`
/// los arreglos vienen vacíos y las secciones simplemente no aparecen.
class LogisticsSiteReadonly extends StatelessWidget {
  final LogisticsSite site;

  /// Muestra el encabezado "idSitio - nombreSitio". El form de entrega lo oculta
  /// (el checkbox ya provee el título) para no duplicarlo.
  final bool showHeader;

  const LogisticsSiteReadonly({super.key, required this.site, this.showHeader = true});

  static String _s(dynamic v) => v?.toString() ?? '';

  List<VisualTitle<String>> _evidenceImages() {
    final out = <VisualTitle<String>>[];
    for (var i = 0; i < site.evidencias.length; i++) {
      final e = site.evidencias[i];
      if (e is! Map) continue;
      final key = _s(e['archivo']);
      if (key.isEmpty) continue;
      final tipo = _s(e['tipo']);
      out.add(VisualTitle<String>(tipo.isNotEmpty ? tipo : 'Evidencia ${i + 1}', solvedUrl(key)));
    }
    return out;
  }

  List<VisualTitle<String>> _tarimaImages() {
    final out = <VisualTitle<String>>[];
    for (var i = 0; i < site.tarimas.length; i++) {
      final t = site.tarimas[i];
      if (t is! Map) continue;
      final tarima = _s(t['tarimaFoto']);
      final papeleta = _s(t['papeletaFoto']);
      if (tarima.isNotEmpty) out.add(VisualTitle<String>('Tarima ${i + 1}', solvedUrl(tarima)));
      if (papeleta.isNotEmpty) out.add(VisualTitle<String>('Papeleta ${i + 1}', solvedUrl(papeleta)));
    }
    return out;
  }

  String _tiposText() =>
      site.tiposMaterial.whereType<Map>().map((e) => _s(e['tipo'])).where((s) => s.isNotEmpty).join(', ');

  String _incidenciasText() =>
      site.incidencias.whereType<Map>().map((e) => _s(e['tipo'])).where((s) => s.isNotEmpty).join(', ');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tipos = _tiposText();
    final incidencias = _incidenciasText();
    final evidencias = _evidenceImages();
    final tarimas = _tarimaImages();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            if (showHeader)
              Text(
                '${site.idSitio} - ${site.nombreSitio}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            if (site.descripcionMaterial.isNotEmpty) LabelValue('Material', site.descripcionMaterial),
            if (tipos.isNotEmpty) LabelValue('Tipos', tipos),
            if (site.materialFaltante)
              Row(
                spacing: 6,
                children: [
                  Icon(Icons.report_problem_outlined, size: 16, color: colorScheme.error),
                  Expanded(
                    child: Text(
                      site.descripcionFaltantes?.isNotEmpty == true
                          ? 'Material faltante: ${site.descripcionFaltantes}'
                          : 'Material faltante',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            if (incidencias.isNotEmpty) LabelValue('Incidencias', incidencias),
            if (site.descripcionIncidencias?.isNotEmpty == true)
              LabelValue('Detalle de incidencias', site.descripcionIncidencias),
            if (evidencias.isNotEmpty || tarimas.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  if (evidencias.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => showImagesDialog(context, images: evidencias),
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: Text('EVIDENCIAS (${evidencias.length})'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  if (tarimas.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => showImagesDialog(context, images: tarimas),
                      icon: const Icon(Icons.view_module_outlined, size: 16),
                      label: Text('TARIMAS (${site.tarimas.length})'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
