import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/widgets/media/visual_dialogs.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/features/material_validation/data/material_validation_service.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';
import 'package:gaso_tenant_app/features/material_validation/presentation/material_validation_out_flow.dart';

class MaterialValidationDetail extends StatefulWidget {
  final MaterialValidation? materialValidation;
  final String? folio;

  const MaterialValidationDetail({super.key, this.materialValidation, this.folio})
    : assert(materialValidation != null || folio != null, 'Se requiere material o folio');

  @override
  State<MaterialValidationDetail> createState() => _MaterialValidationDetailState();
}

class _MaterialValidationDetailState extends State<MaterialValidationDetail> {
  final MaterialValidationService _materialValidationService = MaterialValidationService();
  MaterialValidation? _materialValidation;
  bool _isLoading = true;
  bool _isES = true;

  @override
  void initState() {
    super.initState();
    if (widget.materialValidation != null) {
      _materialValidation = widget.materialValidation;
      _isES = _materialValidation?.es ?? true;
      _isLoading = false;
    } else {
      _fetchByFolio();
    }
  }

  Future<void> _fetchByFolio() async {
    try {
      final response = await _materialValidationService.getByFolio(widget.folio!);
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _materialValidation = response.data;
          _isES = _materialValidation?.es ?? true;
        });
      } else {
        MessengerService.error(response.message);
      }
    } catch (e) {
      MessengerService.error('Error al obtener el registro');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String title = 'Material de ${_isES ? 'Entrada' : 'Salida'}';

    return Scaffold(
      appBar: AppBarHeader(title),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _materialValidation == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  const Text('No se encontró el registro'),
                ],
              ),
            )
          : _buildContent(colorScheme),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final vm = _materialValidation!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          _HeaderCard(vm: vm, isES: _isES, colorScheme: colorScheme),
          ..._outActions(vm),
          _Section(
            title: _isES ? 'Entrada' : 'Salida',
            children: [
              LabelValue('Fecha', getFormattedDateStr(vm.fecha, 'dd/MM/yyyy')),
              LabelValue('Tipo de material', vm.tipoMaterial),
              LabelValue('Id Sitio', vm.idSitio),
              LabelValue('Nombre Sitio', vm.nombreSitio),
              LabelValue('Cuenta / Cliente', vm.cuentaCliente),
              LabelValue('Nombre ASP', vm.aspNombre),
              LabelValue('Nombre del contacto', vm.nombreContacto),
              LabelValue('Carrier', vm.idCarrier != 4 ? vm.carrier : vm.otroCarrier),
              LabelValue('Almacén destino', vm.almacenDestino),
              LabelValue('Región', '${vm.idRegion}'),
              if (vm.notas.isNotEmpty) LabelValue('Notas', vm.notas),
            ],
          ),
          _Section(
            title: 'Transporte',
            trailing: _ImageButton(
              label: 'Ver fotos',
              icon: Icons.photo_library_outlined,
              onTap: () => showImagesDialog(
                context,
                images: [
                  VisualTitle<String>('Transporte', solvedUrl(vm.transporteFoto)),
                  VisualTitle<String>('Placas', solvedUrl(vm.placasFoto)),
                  VisualTitle<String>('En transporte', solvedUrl(vm.materialEnTransporteFoto)),
                  if (_isES) VisualTitle<String>('Descargado', solvedUrl(vm.materialDescargadoFoto)),
                ],
              ),
            ),
            children: [LabelValue('Placas', vm.placasTransporte)],
          ),
          _Section(
            title: 'Registro de piezas',
            trailing: vm.tarimas.isNotEmpty
                ? _ImageButton(
                    label: 'Ver tarimas',
                    icon: Icons.view_module_outlined,
                    onTap: () => showImagesDialog(context, images: imagesFromMap(vm.tarimas)),
                  )
                : null,
            children: [
              LabelValue('Total de piezas ${_isES ? 'recibidas' : 'entregadas'}', '${vm.totalPiezas}'),
              if (vm.numTarimas > 0) LabelValue('Tarimas', '${vm.numTarimas}'),
            ],
          ),
          if (vm.piezasMotivo.isNotEmpty) _PiezasSection(title: 'Piezas por motivo', piezas: vm.piezasMotivo),
          if (vm.piezasEstadoF.isNotEmpty) _PiezasSection(title: 'Piezas por estado físico', piezas: vm.piezasEstadoF),
          if (vm.documentos.isNotEmpty) _DocumentosSection(documentos: vm.documentos, context: context),
          _Section(
            title: 'Firma ASP',
            trailing: _ImageButton(
              label: 'Ver firma',
              icon: Icons.draw_outlined,
              onTap: null, // se asigna abajo
            ),
            children: const [],
          ),
          _FirmaSection(aspFirma: vm.aspFirma, aspNombre: vm.aspNombre, context: context),
          _Section(
            title: 'QR del folio',
            trailing: _ImageButton(
              label: 'Ver QR',
              icon: Icons.qr_code,
              onTap: () => showImagesDialog(
                context,
                images: [VisualTitle<String>('QR', solvedUrl(vm.qr))],
                isQR: true,
                padding: 32,
              ),
            ),
            children: const [],
          ),
          _Section(
            title: 'Registro',
            children: [
              LabelValue('Fecha de captura', getFormattedDateStr(vm.fechaCaptura, 'dd/MM/yyyy HH:mm')),
              if (vm.fechaEdicion != null)
                LabelValue('Última edición', getFormattedDateStr(vm.fechaEdicion!, 'dd/MM/yyyy HH:mm')),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Acción contextual IN→OUT (R4): "Dar salida" (bit W) para una entrada sin
  /// salida, "Ver salida" si ya la tiene, o "Ver entrada de origen" si es una
  /// salida derivada. Lista vacía si no aplica (no ocupa espacio en el layout).
  List<Widget> _outActions(MaterialValidation vm) {
    if (vm.es && vm.folioSalida == null && !vm.cancelada && AuthContext.instance.canWrite('material_validation')) {
      return [
        _ActionCard(
          icon: Icons.logout,
          label: 'Dar salida',
          onTap: () => MaterialValidationOutFlow.runVerifyAndOpenOut(context, vm.folio, inHand: vm),
        ),
      ];
    }
    if (vm.es && vm.folioSalida != null) {
      return [
        _ActionCard(
          icon: Icons.open_in_new,
          label: 'Ver salida',
          onTap: () => Navigator.pushNamed(context, AppRoutes.materialValidationDetail, arguments: vm.folioSalida),
        ),
      ];
    }
    if (!vm.es && vm.folioOrigen != null) {
      return [
        _ActionCard(
          icon: Icons.login,
          label: 'Ver entrada de origen',
          onTap: () => Navigator.pushNamed(context, AppRoutes.materialValidationDetail, arguments: vm.folioOrigen),
        ),
      ];
    }
    return const [];
  }
}

class _HeaderCard extends StatelessWidget {
  final MaterialValidation vm;
  final bool isES;
  final ColorScheme colorScheme;

  const _HeaderCard({required this.vm, required this.isES, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 12,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: vm.cancelada ? colorScheme.errorContainer : colorScheme.primaryContainer,
              child: Icon(
                vm.cancelada ? Icons.block : Icons.category,
                color: vm.cancelada ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vm.proyecto,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(vm.folio, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Text('${isES ? 'Recibió' : 'Entregó'}: ${vm.responsable}'),
                  if (vm.cancelada)
                    Chip(
                      label: const Text('Cancelada'),
                      avatar: Icon(Icons.block, size: 14, color: colorScheme.onError),
                      backgroundColor: colorScheme.error,
                      labelStyle: TextStyle(color: colorScheme.onError),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [SectionTitle(title), ?trailing]),
        const SizedBox(height: 4),
        ...children,
      ],
    );
  }
}

class _PiezasSection extends StatelessWidget {
  final String title;
  final List<dynamic> piezas;

  const _PiezasSection({required this.title, required this.piezas});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var registro in piezas)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text(
                      '${registro['cl'] ?? registro['clt'] ?? '?'}',
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  title: Text('${registro['pzs'] ?? '-'}'),
                  subtitle: (registro['clt'] != null && registro['clt'] != registro['cl'])
                      ? Text('${registro['clt']}')
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentosSection extends StatelessWidget {
  final List<dynamic> documentos;
  final BuildContext context;

  const _DocumentosSection({required this.documentos, required this.context});

  @override
  Widget build(BuildContext outerContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Documentos'),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var doc in documentos)
                ListTile(
                  dense: true,
                  leading: Icon(_isPdf(doc['file']) ? Icons.picture_as_pdf : Icons.image, size: 20),
                  title: Text('${doc['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                  subtitle: Text(_isPdf(doc['file']) ? 'PDF' : 'Imagen', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openDoc(outerContext, doc),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isPdf(String? url) => url?.toLowerCase().contains('.pdf') ?? false;

  void _openDoc(BuildContext ctx, dynamic doc) {
    final raw = doc['file'] as String? ?? '';
    if (raw.isEmpty) return;
    // `file` es la llave completa (Qa/…); anteponemos la raíz del bucket.
    // Guard http:// por si algún registro legacy guardó la URL completa.
    final url = solvedUrl(raw);
    if (_isPdf(url)) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      showImagesDialog(ctx, images: [VisualTitle<String>(doc['name'] ?? 'Documento', url)]);
    }
  }
}

class _FirmaSection extends StatelessWidget {
  final String aspFirma;
  final String aspNombre;
  final BuildContext context;

  const _FirmaSection({required this.aspFirma, required this.aspNombre, required this.context});

  @override
  Widget build(BuildContext outerContext) {
    final Uint8List firmaBytes = base64Decode(aspFirma);
    return GestureDetector(
      onTap: () => showSignaturesDialog(outerContext, signatures: [VisualTitle<Uint8List>('Firma ASP', firmaBytes)]),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 100,
              color: Colors.white,
              child: Image.memory(firmaBytes, fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(aspNombre, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ImageButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }
}
