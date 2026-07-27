import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/list/base_list_screen.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/storage/preferences.dart';
import 'package:gaso_tenant_app/core/widgets/selection/options.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/widgets/forms/dialogs.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/material_logistics_service.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/selection_lists.dart';

class MaterialLogisticsList extends StatefulWidget {
  const MaterialLogisticsList({super.key});

  @override
  State<MaterialLogisticsList> createState() => _MaterialLogisticsListState();
}

class _MaterialLogisticsListState extends BaseListScreen<MaterialLogisticsList, MaterialLogistics> {
  final MaterialLogisticsService _service = MaterialLogisticsService();
  final XdocksSL _xdocksSL = XdocksSL();
  final CarriersSL _carriersSL = CarriersSL();
  final Preferences _preferences = Preferences();
  final ValueNotifier<String?> _xdock = ValueNotifier(null);
  final ValueNotifier<String?> _carrier = ValueNotifier(null);
  final ValueNotifier<String> _sort = ValueNotifier('DESC');
  bool _re = true; // true = Recepciones, false = Entregas

  @override
  String get screenTitle => _re ? 'Recepción de material' : 'Entrega de material';

  @override
  String get emptyMessage => _re ? 'No hay recepciones registradas.' : 'No hay entregas registradas.';

  @override
  bool get hasFloatingActionButton => true;

  @override
  String? get floatingActionRoute => AppRoutes.materialLogistics; // ruta del form (crear)

  @override
  int get limit => 10;

  @override
  Future<void> onInitSuccess() async {
    await _preferences.init();
    if (mounted) {
      // Si nunca ha elegido (lmRE == null), arranca en Recepciones sin persistir.
      setState(() => _re = _preferences.lmRE ?? true);
    }
  }

  @override
  void onDispose() {
    _service.dispose();
    _xdock.dispose();
    _carrier.dispose();
    _sort.dispose();
  }

  @override
  Future<List<MaterialLogistics>> fetchData() async {
    final formData = <String, dynamic>{
      're': _re,
      'idXdock': _xdock.value,
      'idCarrier': _carrier.value,
    };
    formData.removeWhere((key, value) => value == null);
    final response = await _service.getRecords(
      formData,
      page: currentPage,
      limit: limit,
      sort: _sort.value,
    );
    if (!response.success || response.data == null) MessengerService.error(response.message);
    return response.data!;
  }

  @override
  List<Widget>? buildAppBarActions() {
    return [
      IconButton(tooltip: 'Recepción o Entrega', onPressed: _switchRE, icon: const Icon(Icons.swap_horiz)),
      IconButton(tooltip: 'Filtros', onPressed: _showFilters, icon: const Icon(Icons.filter_list)),
    ];
  }

  /// Invierte el tipo mostrado y persiste la preferencia (lmRE).
  void _switchRE() {
    setState(() => _re = !_re);
    _preferences.lmRE = _re;
    loadRegistros();
  }

  @override
  void clearFilters() {
    setState(() {
      _xdock.value = null;
      _carrier.value = null;
    });
  }

  void _showFilters() {
    showFilterModal(
      context,
      onClean: () => clearFilters(),
      onFilter: () {
        Navigator.pop(context);
        loadRegistros();
      },
      children: [
        OptionSelector<String?>(
          title: 'XDOCK',
          optionsMap: _xdocksSL.list.toTVMap(),
          valueNotifier: _xdock,
          clearValue: null,
        ),
        OptionSelector<String?>(
          title: 'Carrier',
          optionsMap: _carriersSL.list.toTVMap(),
          valueNotifier: _carrier,
          clearValue: null,
        ),
        OptionSelector<String>(
          title: 'Ordenar',
          optionsMap: {"Desde más recientes": 'DESC', "Desde más antiguos": 'ASC'},
          valueNotifier: _sort,
          clearValue: 'DESC',
        ),
      ],
    );
  }

  String _hhmm(String? t) => (t != null && t.length >= 5) ? t.substring(0, 5) : (t ?? '—');

  /// Detalle de cabecera (sin material/incidencias: esos viven por sitio → acción Sitios).
  Future<void> _showDetails(MaterialLogistics ml) {
    return showDetailsDialog(context, ml.re ? 'Recepción' : 'Entrega', [
      LabelValue('Folio', ml.folio),
      LabelValue('XDOCK', ml.xdock),
      LabelValue('Carrier', ml.idCarrier != 4 ? ml.carrier : (ml.otroCarrier ?? '—')),
      LabelValue('Unidad / placa', ml.unidadPlaca),
      LabelValue('Operador', ml.nombreOperador),
      const SectionTitle('Control de arribo'),
      LabelValue('Llegada', _hhmm(ml.horaLlegada)),
      LabelValue('Inicio ${ml.re ? "descarga" : "carga"}', _hhmm(ml.horaInicioDescarga)),
      LabelValue('Salida', _hhmm(ml.horaSalida)),
      const SectionTitle('Registro'),
      LabelValue('Fecha', getFormattedDateStr(ml.fecha, 'dd/MM/yyyy')),
      if (ml.fechaEdicion != null) LabelValue('Edición', getFormattedDateStr(ml.fechaEdicion!, 'dd/MM/yyyy')),
      LabelValue('Sitios', '${ml.sitios.length}'),
    ]);
  }

  /// Drill-down de sitios: tarjetas estilo SitesScreen; el tap abre el detalle del sitio.
  Future<void> _showSites(MaterialLogistics ml) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sitios'),
        content: SizedBox(
          width: double.maxFinite,
          child: ml.sitios.isEmpty
              ? const Text('Sin sitios.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in ml.sitios)
                      ListTile(
                        dense: true,
                        title: Text(
                          '${s.idSitio}-${s.nombreSitio}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${s.tiposMaterial.length} tipo(s) · ${s.evidencias.length} evidencia(s) · ${s.tarimas.length} tarima(s)',
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _showSiteDetail(s),
                      ),
                  ],
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  Future<void> _showSiteDetail(LogisticsSite site) {
    final types = site.tiposMaterial.map((t) => (t as Map)['tipo']).join(', ');
    final evidences = site.evidencias.map((e) => e as Map).toList();
    final pallets = site.tarimas.map((p) => p as Map).toList();
    final incidences = site.incidencias.map((i) => (i as Map)['tipo']).join(', ');
    pallets.sort((t1, t2) => t1['orden'] - t2['orden']);

    return showDetailsDialog(context, 'Sitio', [
      LabelValue('Id', site.idSitio),
      LabelValue('Nombre', site.nombreSitio),
      const SectionTitle('Material'),
      LabelValue('Tipo de material', types.isEmpty ? '—' : types),
      LabelValue('Descripción', site.descripcionMaterial),
      LabelValue('Faltante', site.materialFaltante ? 'Sí' : 'No'),
      if (site.materialFaltante) LabelValue('Detalle faltantes', site.descripcionFaltantes ?? '—'),
      const SectionTitle('Evidencias'),
      SizedBox(height: 4),
      for (int i = 0; i < evidences.length; i++) _fileItem(evidences[i], 'tipo', 'archivo'),
      for (int i = 0; i < pallets.length; i++) _palletItem(pallets[i], i),
      if (incidences.isNotEmpty) ...[
        const SectionTitle('Incidencias'),
        SizedBox(height: 4),
        LabelValue('Tipos', incidences.isEmpty ? 'Ninguna' : incidences),
        LabelValue('Descripción', site.descripcionIncidencias ?? 'Sin descripción'),
      ],
    ]);
  }

  Widget _fileItem(Map item, String nameKey, String fileKey) {
    try {
      final String archivo = '${item[fileKey] ?? ''}';
      return InfoRow(
        item[nameKey],
        onAction: () => _verDocumento(archivo),
        actionIcon: Icons.file_open,
      );
    } catch (e) {
      DebugLog.warning('_fileItem - $e');
      return LabelValue('Sin registro', 'error al obtener los datos');
    }
  }

  Widget _palletItem(Map pallet, int idx) {
    try {
      final String tarimaFoto = '${pallet['tarimaFoto'] ?? ''}';
      final String papeletaFoto = '${pallet['papeletaFoto'] ?? ''}';
      return InfoActionsRow(
        'Tarima/Papeleta',
        label: 'Pallet ${idx + 1}',
        onActionOne: () => _verDocumento(tarimaFoto),
        actionIconOne: Icons.pallet,
        onActionTwo: () => _verDocumento(papeletaFoto),
        actionIconTwo: Icons.note,
      );
    } catch (e) {
      DebugLog.warning('_evidenciaItem - $e');
      return LabelValue('Sin evidencia', 'error al obtener los datos');
    }
  }

  Future<void> _verDocumento(String archivo) async {
    try {
      final uri = Uri.parse('${Config.s3Url}$archivo');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        MessengerService.info('No se pudo abrir el archivo $archivo');
      }
    } catch (e) {
      DebugLog.warning('_verDocumento - $e');
      MessengerService.info('No se pudo abrir el documento.');
    }
  }

  /// Trae el detalle completo y abre el form en edición; al volver con `true`, refresca.
  Future<void> _openEdit(MaterialLogistics ml) async {
    final response = await _service.getByFolio(ml.folio);
    if (!mounted) return;
    if (!response.success || response.data == null) {
      return MessengerService.error(response.message);
    }
    final result = await Navigator.pushNamed(context, AppRoutes.materialLogistics, arguments: response.data);
    if (result == true && mounted) loadRegistros();
  }

  @override
  Widget buildListItem(BuildContext context, MaterialLogistics item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 0),
        titleAlignment: ListTileTitleAlignment.top,
        title: Text(item.folio, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(child: Text(item.xdock, overflow: TextOverflow.ellipsis, maxLines: 1)),
                Text(getFormattedDateStr(item.fecha, 'dd/MM/yy')),
              ],
            ),
            Text('${item.sitios.length} sitio(s)'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'details':
                await _showDetails(item);
                break;
              case 'sites':
                await _showSites(item);
                break;
              case 'edit':
                await _openEdit(item);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'details', child: Text('Detalles')),
            if (item.sitios.isNotEmpty) const PopupMenuItem(value: 'sites', child: Text('Sitios')),
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
          ],
        ),
        onTap: () => _showDetails(item),
      ),
    );
  }
}
