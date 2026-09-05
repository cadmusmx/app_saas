import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/widgets/media/visual_dialogs.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/material_logistics_service.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/logistics_site_readonly.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/material_logistics_out_flow.dart';

/// Detalle read-only de un registro de Logística (recepción o entrega). Punto de
/// aterrizaje del escaneo (§3.1) y del "Ver entregas"/"Ver recepción de origen".
/// Acepta el registro completo (desde la lista) o solo el folio (desde el scan),
/// y en el segundo caso se auto-fetchea con `getByFolio`.
///
/// Barra de acción **ortogonal** (acordado): "Ver entregas" ⟺ `hasDeliveries`,
/// "Ver recepción de origen" ⟺ `hasOrigin`. La acción de **escritura** "Entregar"
/// (⟺ `canDeliver` + bit W) se cablea en el paso 3 (out_flow).
class MaterialLogisticsDetail extends StatefulWidget {
  final MaterialLogistics? record;
  final String? folio;

  const MaterialLogisticsDetail({super.key, this.record, this.folio})
    : assert(record != null || folio != null, 'Se requiere el registro o el folio');

  @override
  State<MaterialLogisticsDetail> createState() => _MaterialLogisticsDetailState();
}

class _MaterialLogisticsDetailState extends State<MaterialLogisticsDetail> {
  final MaterialLogisticsService _service = MaterialLogisticsService();
  MaterialLogistics? _ml;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _ml = widget.record;
      _isLoading = false;
    } else {
      _fetchByFolio();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _fetchByFolio() async {
    final res = await _service.getByFolio(widget.folio!);
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() => _ml = res.data);
    } else {
      MessengerService.error(res.message);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _openFolio(String? folio) {
    if (folio == null || folio.isEmpty) return;
    Navigator.pushNamed(context, AppRoutes.materialLogisticsDetail, arguments: folio);
  }

  void _showEntregas(MaterialLogistics ml) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Entregas (${ml.entregas.length})', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in ml.entregas)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(e.folio, style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: e.fecha.isNotEmpty ? Text(getFormattedDateStr(e.fecha, 'dd/MM/yyyy')) : null,
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openFolio(e.folio);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _ml == null ? 'Detalle' : (_ml!.re ? 'Recepción de material' : 'Entrega de material');
    return Scaffold(
      appBar: AppBarHeader(title),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ml == null
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
    final ml = _ml!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          _HeaderCard(ml: ml, colorScheme: colorScheme),
          ..._outActions(ml),
          _Section(
            title: ml.re ? 'Datos de la recepción' : 'Datos de la entrega',
            children: [
              LabelValue('Fecha', getFormattedDateStr(ml.fecha, 'dd/MM/yyyy')),
              LabelValue('XDOCK', ml.xdock),
              LabelValue('Responsable', ml.nombreResponsable ?? ml.responsable),
              LabelValue('Unidad / Placa', ml.unidadPlaca),
              LabelValue('Operador', ml.nombreOperador),
              LabelValue('Hora de llegada', ml.horaLlegada),
              LabelValue(ml.re ? 'Inicio de descarga' : 'Inicio de carga', ml.horaInicioDescarga),
              LabelValue('Hora de salida', ml.horaSalida),
              LabelValue('Carrier', ml.esOtro ? ml.otroCarrier : ml.carrier),
              LabelValue('Confirmado', ml.confirmado ? 'Sí' : 'No'),
            ],
          ),
          _Section(title: 'Sitios (${ml.sitios.length})', children: [for (final s in ml.sitios) _siteBlock(s)]),
          if (ml.documentos.isNotEmpty) _DocumentosSection(documentos: ml.documentos),
          if (ml.qr.isNotEmpty)
            _Section(
              title: 'QR del folio',
              trailing: _ImageButton(
                label: 'VER QR',
                icon: Icons.qr_code,
                onTap: () => showImagesDialog(
                  context,
                  images: [VisualTitle<String>('QR', solvedUrl(ml.qr))],
                  isQR: true,
                  padding: 32,
                ),
              ),
              children: const [],
            ),
          _Section(
            title: 'Registro',
            children: [
              LabelValue('Fecha de captura', getFormattedDateStr(ml.fechaCreacion, 'dd/MM/yyyy HH:mm')),
              if (ml.fechaEdicion != null)
                LabelValue('Última edición', getFormattedDateStr(ml.fechaEdicion!, 'dd/MM/yyyy HH:mm')),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Un sitio: material read-only (widget compartido) + estado de entrega
  /// (chip "Entregado" con enlace a su `folioEntrega`, si aplica).
  Widget _siteBlock(LogisticsSite s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.entregado)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: (s.folioEntrega != null && s.folioEntrega!.isNotEmpty)
                  ? ActionChip(
                      avatar: const Icon(Icons.check_circle, size: 16),
                      label: Text('Entregado · ${s.folioEntrega}'),
                      onPressed: () => _openFolio(s.folioEntrega),
                    )
                  : const Chip(avatar: Icon(Icons.check_circle, size: 16), label: Text('Entregado')),
            ),
          ),
        LogisticsSiteReadonly(site: s),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Barra de acción read-only (ortogonal). "Entregar" se agrega en el paso 3.
  List<Widget> _outActions(MaterialLogistics ml) {
    final actions = <Widget>[];
    if (ml.canDeliver && AuthContext.instance.canWrite('material_logistics')) {
      actions.add(
        _ActionCard(
          icon: Icons.local_shipping,
          label: 'Entregar',
          onTap: () => MaterialLogisticsOutFlow.runVerifyAndOpenOut(context, ml.folio),
        ),
      );
    }
    if (ml.hasDeliveries) {
      actions.add(_ActionCard(icon: Icons.list_alt, label: 'Ver entregas', onTap: () => _showEntregas(ml)));
    }
    if (ml.hasOrigin) {
      actions.add(
        _ActionCard(icon: Icons.login, label: 'Ver recepción de origen', onTap: () => _openFolio(ml.folioIN)),
      );
    }
    return actions;
  }
}

class _HeaderCard extends StatelessWidget {
  final MaterialLogistics ml;
  final ColorScheme colorScheme;

  const _HeaderCard({required this.ml, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (ml.extended) const Chip(label: Text('Con entregas'), visualDensity: VisualDensity.compact),
      if (ml.closed) const Chip(label: Text('Cerrada'), visualDensity: VisualDensity.compact),
      if (ml.esDerivada) const Chip(label: Text('Derivada'), visualDensity: VisualDensity.compact),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          spacing: 12,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(ml.re ? Icons.call_received : Icons.call_made, color: colorScheme.onPrimaryContainer),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ml.xdock.isNotEmpty ? ml.xdock : (ml.re ? 'Recepción' : 'Entrega'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(ml.folio, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Text('${ml.re ? 'Recibió' : 'Entregó'}: ${ml.nombreResponsable ?? ml.responsable}'),
                  if (chips.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
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
      spacing: 6,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [SectionTitle(title), ?trailing]),
        ...children,
      ],
    );
  }
}

class _DocumentosSection extends StatelessWidget {
  final List<dynamic> documentos;

  const _DocumentosSection({required this.documentos});

  bool _isPdf(String? s) => s?.toLowerCase().contains('.pdf') ?? false;

  void _open(BuildContext ctx, Map doc) {
    final key = doc['archivo']?.toString() ?? '';
    if (key.isEmpty) return;
    final url = solvedUrl(key);
    final isPdf = _isPdf(key) || (doc['mimeType']?.toString().contains('pdf') ?? false);
    if (isPdf) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      showImagesDialog(ctx, images: [VisualTitle<String>(doc['nombre']?.toString() ?? 'Documento', url)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Documentos'),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final doc in documentos.whereType<Map>())
                ListTile(
                  dense: true,
                  leading: Icon(
                    (_isPdf(doc['archivo']?.toString()) || (doc['mimeType']?.toString().contains('pdf') ?? false))
                        ? Icons.picture_as_pdf
                        : Icons.image,
                    size: 20,
                  ),
                  title: Text('${doc['nombre'] ?? ''}', overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open(context, doc),
                ),
            ],
          ),
        ),
      ],
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
      label: Text(label.toUpperCase()),
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
        label: Text(label.toUpperCase()),
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }
}
