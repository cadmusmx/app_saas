import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/widgets/forms/dialogs.dart';
import 'package:gaso_tenant_app/core/widgets/selection/options.dart';
import 'package:gaso_tenant_app/core/widgets/media/visual_dialogs.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/storage/preferences.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/list/base_list_screen.dart';
import 'package:gaso_tenant_app/features/material_validation/data/material_validation_service.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';
import 'package:gaso_tenant_app/features/material_validation/presentation/material_validation_form.dart';
import 'package:gaso_tenant_app/features/material_validation/data/material_catalogs_service.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_catalogs.dart';

class MaterialValidationList extends StatefulWidget {
  const MaterialValidationList({super.key});

  @override
  State<MaterialValidationList> createState() => _MaterialValidationListState();
}

class _MaterialValidationListState extends BaseListScreen<MaterialValidationList, MaterialValidation> {
  final MaterialValidationService _materialService = MaterialValidationService();
  MaterialCatalogs? _catalogs;
  final Preferences _preferences = Preferences();
  final ValueNotifier<String?> _type = ValueNotifier(null);
  final ValueNotifier<String?> _condition = ValueNotifier(null);
  final ValueNotifier<String> _sort = ValueNotifier('DESC');
  bool _es = true;

  @override
  String get screenTitle => 'Validación de ${_es ? 'entradas' : 'salidas'}';

  @override
  String get emptyMessage => 'No hay registros.';

  @override
  bool get hasFloatingActionButton => true;

  @override
  String? get floatingActionRoute => AppRoutes.materialValidation;

  @override
  int get limit => 10;

  @override
  Future<void> onInitSuccess() async {
    await _preferences.init();
    if (mounted) {
      // Si nunca ha elegido (lmRE == null), arranca en Recepciones sin persistir.
      setState(() => _es = _preferences.vmES ?? true);
    }
    try {
      _catalogs = await MaterialCatalogsCache.instance.load();
    } catch (e) {
      DebugLog.warning('catalogs (lista): $e');
    }
  }

  @override
  void onDispose() {
    _materialService.dispose();
  }

  @override
  Future<List<MaterialValidation>> fetchData() async {
    // Listado general del tenant (Perm.R): NO se filtra por idUsuario; se ven
    // todos los registros. La edición sigue gateada al dueño en cada item.
    // Los filtros "Tipo"/"Condición" de la UI son en realidad proyecto/tipoMaterial.
    final filters = <String, dynamic>{
      'es': _es,
      'proyecto': int.tryParse(_type.value ?? ''),
      'tipoMaterial': int.tryParse(_condition.value ?? ''),
    };
    filters.removeWhere((key, value) => value == null);
    final response = await _materialService.getRecords(filters, limit: limit, page: currentPage, sort: _sort.value);
    if (!response.success) MessengerService.error(response.message);
    return response.data ?? [];
  }

  @override
  List<Widget>? buildAppBarActions() {
    return [
      IconButton(tooltip: 'Entrada o Salida', onPressed: _switchES, icon: const Icon(Icons.swap_horiz)),
      IconButton(tooltip: 'Filtros', onPressed: _showFilters, icon: const Icon(Icons.filter_list)),
    ];
  }

  @override
  void clearFilters() {
    setState(() {
      _type.value = null;
      _condition.value = null;
    });
  }

  Future<void> _showFilters() async {
    showFilterModal(
      context,
      onClean: () => clearFilters(),
      onFilter: () {
        Navigator.pop(context);
        loadRegistros();
      },
      children: [
        OptionSelector<String?>(
          title: 'Tipo',
          optionsMap: (_catalogs?.projects ?? const <OptionSL>[]).toTVMap(),
          valueNotifier: _type,
          clearValue: null,
        ),
        OptionSelector<String?>(
          title: 'Condición',
          optionsMap: (_catalogs?.materialTypes ?? const <OptionSL>[]).toTVMap(),
          valueNotifier: _condition,
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

  Future<void> _showDetails(MaterialValidation vm) async {
    return showDetailsDialog(context, vm.proyecto, [
      LabelValue('Folio', vm.folio),
      LabelValue(_es ? 'Recibió' : 'Entregó', vm.responsable),
      LabelValue('Región', vm.idRegion),
      SectionTitle(_es ? 'Entrada' : 'Salida'),
      LabelValue('Fecha', getFormattedDateStr(vm.fecha, 'dd/MM/yyyy')),
      LabelValue('Tipo de material', vm.tipoMaterial),
      LabelValue('Id sitio', vm.idSitio),
      LabelValue('Nombre sitio', vm.nombreSitio),
      LabelValue('Cuenta / Cliente', vm.cuentaCliente),
      LabelValue('Nombre ASP', vm.aspNombre),
      LabelValue('Nombre del contacto', vm.nombreContacto),
      LabelValue('Carrier', vm.idCarrier != 4 ? vm.carrier : vm.otroCarrier),
      LabelValue('Almacén destino', vm.almacenDestino),
      const SectionTitle('Transporte y material'),
      LabelValue('Placas del transporte', vm.placasTransporte),
      LabelValue('Total de piezas', vm.totalPiezas),
      if (vm.numTarimas > 0) LabelValue('Tarimas', vm.numTarimas),
      LabelValue('Observaciones y notas', vm.notas),
      LabelValue('Fecha de captura', getFormattedDateStr(vm.fechaCaptura, 'dd/MM/yyyy')),
      if (vm.fechaEdicion != null) LabelValue('Fecha de edición', getFormattedDateStr(vm.fechaEdicion!, 'dd/MM/yyyy')),
    ]);
  }

  Future<void> _showDocuments(MaterialValidation vm) async {
    bool isPdf(String? url) => url?.toLowerCase().contains('.pdf') ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Documentos'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var doc in vm.documentos)
                ListTile(
                  dense: true,
                  leading: Icon(isPdf(doc['file']) ? Icons.picture_as_pdf : Icons.image, size: 20),
                  title: Text('${doc['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    final url = doc['file'] as String? ?? '';
                    if (url.isEmpty) return;
                    if (isPdf(url)) {
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    } else {
                      Navigator.pop(ctx);
                      showImagesDialog(context, images: [VisualTitle<String>(doc['name'] ?? 'Documento', url)]);
                    }
                  },
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  void _switchES() {
    setState(() => _es = !_es);
    _preferences.vmES = _es;
    loadRegistros();
  }

  @override
  Widget buildListItem(BuildContext context, MaterialValidation vm, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 0),
        titleAlignment: ListTileTitleAlignment.top,
        title: Text(vm.proyecto, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              spacing: 8,
              children: [
                Icon(Icons.inventory_sharp, color: vm.cancelada ? colorScheme.error : null),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vm.tipoMaterial, overflow: TextOverflow.ellipsis, maxLines: 1),
                      Text(vm.folio),
                      Text(getFormattedDateStr(vm.fecha, 'dd/MM/yy')),
                    ],
                  ),
                ),
              ],
            ),
            if (vm.cancelada)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  Icon(Icons.block, size: 16, color: colorScheme.error),
                  Text('Cancelada', style: TextStyle(color: colorScheme.error)),
                ],
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'details':
                await _showDetails(vm);
                break;
              case 'sign':
                await showSignaturesDialog(
                  context,
                  signatures: [VisualTitle<Uint8List>('Firma ASP', base64Decode(vm.aspFirma))],
                );
                break;
              case 'images':
                DebugLog.info('${Config.s3Url}${vm.transporteFoto}');
                await showImagesDialog(
                  context,
                  images: [
                    VisualTitle<String>('Transporte', '${Config.s3Url}${vm.transporteFoto}'),
                    VisualTitle<String>('Placas', '${Config.s3Url}${vm.placasFoto}'),
                    VisualTitle<String>('En transporte', '${Config.s3Url}${vm.materialEnTransporteFoto}'),
                    if (_es) VisualTitle<String>('Descargado', '${Config.s3Url}${vm.materialDescargadoFoto}'),
                  ],
                );
                break;
              case 'reason-pieces':
                await showDetailsDialog(context, 'Motivo', [
                  for (var registro in vm.piezasMotivo) LabelValue(registro['clt'], registro['pzs']),
                ]);
                break;
              case 'condition-pieces':
                await showDetailsDialog(context, 'Estado físico', [
                  for (var registro in vm.piezasEstadoF) LabelValue(registro['clt'], registro['pzs']),
                ]);
                break;
              case 'documents':
                await _showDocuments(vm);
                break;
              case 'pallets':
                await showImagesDialog(context, images: imagesFromMap(vm.tarimas));
                break;
              case 'qr':
                await showImagesDialog(
                  context,
                  images: [VisualTitle<String>('QR', '${Config.s3Url}${vm.qr}')],
                  isQR: true,
                  padding: 32,
                );
                break;
              case 'edit':
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (context) => MaterialValidationForm(materialValidation: vm)),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'details', child: Text('Detalles')),
            const PopupMenuItem(value: 'sign', child: Text('Firma ASP')),
            const PopupMenuItem(value: 'images', child: Text('Imágenes')),
            if (vm.piezasMotivo.isNotEmpty)
              const PopupMenuItem(value: 'reason-pieces', child: Text('Piezas por motivo')),
            if (vm.piezasEstadoF.isNotEmpty)
              const PopupMenuItem(value: 'condition-pieces', child: Text('Piezas por estado físico')),
            if (vm.documentos.isNotEmpty) const PopupMenuItem(value: 'documents', child: Text('Documentos')),
            if (vm.tarimas.entries.isNotEmpty) const PopupMenuItem(value: 'pallets', child: Text('Tarimas')),
            const PopupMenuItem(value: 'qr', child: Text('QR')),
            if (vm.status == 0 && !vm.cancelada && vm.isOwnedBy(sessionUser.user.id))
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
          ],
        ),
        onTap: () => _showDetails(vm),
      ),
    );
  }
}
