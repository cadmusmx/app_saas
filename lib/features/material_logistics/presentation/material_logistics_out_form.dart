import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/extensions/extensions.dart';
import 'package:gaso_tenant_app/core/forms/controllers_manager.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/helpers/generators_helper.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/services/date_time_picker_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/services/qr_service.dart';
import 'package:gaso_tenant_app/core/services/s3_service.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/material_logistics_service.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/logistics_site_readonly.dart';

/// Form de **entrega derivada** (OutDerived) de Logística de Material.
///
/// El material se hereda de la recepción [materialIn] y va **read-only**: se
/// eligen los **sitios pendientes** a entregar (§3.3.2, llave = `sitios[].id`) y
/// se capturan los datos generales. Al enviar se genera `folioOut`
/// (`getFolio(userId, 'LME-<idXdock>')`), se renderiza y sube su QR, y se hace
/// `POST /out?directQR=true`. El candado `ALL_DELIVERED` ya lo validó
/// `verify-folio`; el **409** (un sitio ya entregado) es el backstop recuperable.
class MaterialLogisticsOutForm extends StatefulWidget {
  final MaterialLogistics? materialIn;
  const MaterialLogisticsOutForm({super.key, required this.materialIn});

  @override
  State<MaterialLogisticsOutForm> createState() => _MaterialLogisticsOutFormState();
}

class _MaterialLogisticsOutFormState extends State<MaterialLogisticsOutForm> {
  late final SessionUser _sessionUser;
  late MaterialLogistics _in; // reasignable: se refresca tras un 409 recuperable
  bool _sessionReady = false;

  final _formKey = GlobalKey<FormState>();
  final MaterialLogisticsService _service = MaterialLogisticsService();
  final S3Service _s3Service = S3Service();
  final QrService _qrService = QrService();
  final ControllersManager _controllers = ControllersManager();

  DateTime _fechaForm = DateTime.now();
  String? _horaLlegada; // "HH:mm:ss"
  String? _horaInicioDescarga;
  String? _horaSalida;
  bool _confirmado = false;

  /// Sitios pendientes elegidos (llave = `LogisticsSite.id`, PK).
  final Set<int> _selectedSiteIds = {};

  /// Docs del IN (read-only) + nuevos que agregue el usuario.
  List<Map<String, dynamic>> _inheritedDocs = [];
  final List<Map<String, dynamic>> _newDocs = []; // { nombre, localPath, mimeType }

  late final String _photosFolder;
  bool _isSubmitting = false;

  String _deepLink(String folio) => 'gasosaas://ml/$folio';

  @override
  void initState() {
    super.initState();
    final session = AuthContext.instance.current;
    final material = widget.materialIn;
    if (session == null || session.user.id == null || material == null || material.sitiosPendientes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MessengerService.error('No se pudo cargar la recepción de origen o no tiene sitios pendientes.');
        Navigator.pop(context);
      });
      return;
    }
    _sessionUser = session;
    _in = material;
    _sessionReady = true;
    // Llave base COMPLETA con folder de entorno (Qa/|Pr/), igual que el alta.
    _photosFolder = '${Config.s3Folder}/${_sessionUser.tenant.slug}/material_logistics/';
    _inheritedDocs = _in.documentos
        .whereType<Map>()
        .map((d) => {
              'nombre': d['nombre']?.toString() ?? '',
              'archivo': d['archivo']?.toString() ?? '',
              'mimeType': d['mimeType']?.toString() ?? '',
            })
        .where((d) => (d['archivo'] as String).isNotEmpty)
        .toList();
    _controllers.setValue('nombreResponsable', _sessionUser.user.name);
  }

  @override
  void dispose() {
    _controllers.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final fecha = await DateTimePickerService.pickFechaSola(context, currentValue: _fechaForm);
    if (fecha != null && mounted) setState(() => _fechaForm = fecha);
  }

  Future<void> _pickHora(TimeOfDay? current, ValueChanged<String?> onPicked) async {
    final t = await DateTimePickerService.pickHora(context, currentValue: current);
    if (t != null && mounted) setState(() => onPicked(t.toApiTime()));
  }

  Widget _horaField(String label, String? value, ValueChanged<String?> onPicked) {
    final current = parseApiTime(value);
    return TextFormField(
      readOnly: true,
      decoration: inputDec(
        label,
        hint: '--:--',
        flb: FloatingLabelBehavior.always,
        suffix: IconButton(icon: const Icon(Icons.schedule), onPressed: () => _pickHora(current, onPicked)),
      ),
      controller: TextEditingController(text: current != null ? current.format(context) : ''),
      onTap: () => _pickHora(current, onPicked),
      validator: (_) => value == null ? 'Selecciona la hora' : null,
    );
  }

  String? _validarHoras() {
    final ll = parseApiTime(_horaLlegada);
    final ini = parseApiTime(_horaInicioDescarga);
    final sal = parseApiTime(_horaSalida);
    if (ll == null || ini == null || sal == null) return 'Completa las tres horas';
    if (ini.inMinutes < ll.inMinutes) return 'El inicio de carga no puede ser antes de la llegada';
    if (sal.inMinutes < ini.inMinutes) return 'La salida no puede ser antes del inicio de carga';
    return null;
  }

  // Documentos nuevos (opcionales)
  Future<void> _pickNewDoc() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
    if (picked == null || picked.files.single.path == null) return;
    if (picked.files.single.size > 5 * 1024 * 1024) {
      return MessengerService.info('El archivo supera el máximo de 5 MB.');
    }
    if (!mounted) return;
    final nameController = TextEditingController(text: picked.files.single.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre del documento'),
        content: TextField(controller: nameController, maxLength: 100, decoration: inputDec('Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aceptar')),
        ],
      ),
    );
    if (ok != true) return;
    final ext = picked.files.single.extension?.toLowerCase() ?? '';
    setState(() {
      _newDocs.add({
        'nombre': nameController.text.trim().isEmpty ? picked.files.single.name : nameController.text.trim(),
        'localPath': picked.files.single.path,
        'mimeType': ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg'),
      });
    });
  }

  /// Sube los docs nuevos a S3 (llave completa) y fija su `archivo`. Devuelve la
  /// lista merge lista para el payload, o null si falló alguna subida.
  Future<List<Map<String, dynamic>>?> _buildMergedDocs(int userId) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final uploaded = <Map<String, dynamic>>[];
    for (var i = 0; i < _newDocs.length; i++) {
      final d = _newDocs[i];
      final path = d['localPath'] as String?;
      if (path == null || path.isEmpty) continue;
      final mime = d['mimeType'] as String? ?? 'image/jpeg';
      final ext = mime.contains('pdf') ? 'pdf' : (mime.contains('png') ? 'png' : 'jpg');
      final key = '${_photosFolder}docs/$userId/$stamp-out-$i.$ext';
      final bytes = await File(path).readAsBytes();
      final url = await _s3Service.uploadU8LToS3(bytes, key, mime);
      if (url == null) return null;
      uploaded.add({'nombre': d['nombre'], 'archivo': key, 'mimeType': mime});
    }
    // Merge: IN (read-only, keys as-is) + nuevos.
    return [..._inheritedDocs, ...uploaded];
  }

  /// Re-fetch tras 409: recomputa pendientes y purga la selección ya no válida.
  Future<void> _refreshPending() async {
    final res = await _service.getByFolio(_in.folio);
    if (!mounted || !res.success || res.data == null) return;
    final pendingIds = res.data!.sitiosPendientes.map((s) => s.id).toSet();
    setState(() {
      _in = res.data!; // recepción fresca
      _selectedSiteIds.removeWhere((id) => !pendingIds.contains(id));
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedSiteIds.isEmpty) return MessengerService.info('Selecciona al menos un sitio a entregar.');
    final horasError = _validarHoras();
    if (horasError != null) return MessengerService.info(horasError);
    if (!_confirmado) return MessengerService.info('Confirma la información antes de enviar.');

    setState(() => _isSubmitting = true);
    try {
      final userId = _sessionUser.user.id!;
      final folioOut = getFolio(userId, 'LME-${_in.idXdock}');

      // Docs merge (sube los nuevos).
      final docs = await _buildMergedDocs(userId);
      if (docs == null) {
        MessengerService.error('Ocurrió un error al subir un documento.');
        return;
      }

      // QR de la entrega (deep link) → S3, llave completa.
      final qrKey = '$_photosFolder$userId/$folioOut.png';
      final qrBytes = await _qrService.generateQrBytes(_deepLink(folioOut));
      final qrUrl = await _s3Service.uploadU8LToS3(qrBytes, qrKey, 'image/png');
      if (qrUrl == null) {
        MessengerService.error('Ocurrió un error al subir el QR a S3.');
        return;
      }

      final resp = _controllers.getValue('nombreResponsable').trim();
      final payload = <String, dynamic>{
        'folioIn': _in.folio,
        'sitios': _selectedSiteIds.toList(),
        'folioOut': folioOut,
        'qr': qrKey,
        'fecha': getFormattedDate(_fechaForm, 'yyyy-MM-dd'),
        // null = derivar del usuario del token; solo mandamos si difiere de la sesión.
        'nombreResponsable': (resp.isEmpty || resp == _sessionUser.user.name) ? null : resp,
        'unidadPlaca': _controllers.getValue('unidadPlaca').trim(),
        'nombreOperador': _controllers.getValue('nombreOperador').trim(),
        'horaLlegada': _horaLlegada,
        'horaInicioDescarga': _horaInicioDescarga,
        'horaSalida': _horaSalida,
        'confirmado': _confirmado,
        if (docs.isNotEmpty) 'documentos': docs,
      };

      final res = await _service.createOut(payload);
      if (!mounted) return;
      if (res.success) {
        _qrService.showQRDialog(
          context,
          _deepLink(folioOut),
          () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.materialLogisticsList,
            (r) => r.settings.name == AppRoutes.home,
          ),
          label: folioOut,
        );
      } else if (res.statusCode == 409) {
        // Recuperable: algún sitio ya fue entregado por otro. Refrescamos
        // pendientes y dejamos reintentar con los restantes (no salimos).
        MessengerService.info('Algún sitio ya fue entregado; se actualizó la lista de pendientes.');
        await _refreshPending();
      } else {
        MessengerService.error(res.message);
      }
    } catch (e) {
      DebugLog.error('OutForm LM _submit: $e');
      MessengerService.error('Ha ocurrido un error inesperado.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pending = _in.sitiosPendientes;
    return Scaffold(
      appBar: const AppBarHeader('Entrega de material'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
                child: Column(
                  spacing: 12,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _resumenIn(),
                    SectionTitle('Sitios a entregar', subtitle: 'Selecciona los pendientes de esta recepción'),
                    for (final s in pending) _siteSelectable(s),
                    SectionTitle('Datos de la entrega'),
                    TextFormField(
                      readOnly: true,
                      decoration: inputDec(
                        'Fecha',
                        flb: FloatingLabelBehavior.always,
                        suffix: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickFecha),
                      ),
                      controller: TextEditingController(text: getFormattedDate(_fechaForm, 'dd/MM/yyyy')),
                      onTap: _pickFecha,
                    ),
                    TextFormField(
                      controller: _controllers.get('nombreResponsable'),
                      decoration: inputDec('Responsable'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    TextFormField(
                      controller: _controllers.get('unidadPlaca'),
                      decoration: inputDec('Unidad / Placa'),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    TextFormField(
                      controller: _controllers.get('nombreOperador'),
                      decoration: inputDec('Operador (chofer)'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    _horaField('Hora de llegada', _horaLlegada, (v) => _horaLlegada = v),
                    _horaField('Inicio de carga', _horaInicioDescarga, (v) => _horaInicioDescarga = v),
                    _horaField('Hora de salida', _horaSalida, (v) => _horaSalida = v),
                    _documentosSection(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Confirmo que la información es correcta'),
                      value: _confirmado,
                      onChanged: (v) => setState(() => _confirmado = v),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.local_shipping),
                        label: Text(_isSubmitting ? 'Enviando…' : 'Registrar entrega'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _resumenIn() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text('Recepción de origen', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            LabelValue('Folio', _in.folio),
            LabelValue('XDOCK', _in.xdock),
            LabelValue('Carrier', _in.esOtro ? _in.otroCarrier : _in.carrier),
          ],
        ),
      ),
    );
  }

  Widget _siteSelectable(LogisticsSite s) {
    final selected = _selectedSiteIds.contains(s.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: selected,
          onChanged: (v) => setState(() => v == true ? _selectedSiteIds.add(s.id) : _selectedSiteIds.remove(s.id)),
          title: Text('${s.idSitio} - ${s.nombreSitio}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        LogisticsSiteReadonly(site: s, showHeader: false),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _documentosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: SectionTitle('Documentos', subtitle: 'Los del arribo se conservan; puedes agregar nuevos.')),
            IconButton(tooltip: 'Agregar documento', icon: const Icon(Icons.add), onPressed: _pickNewDoc),
          ],
        ),
        for (final d in _inheritedDocs)
          ListTile(
            dense: true,
            leading: const Icon(Icons.lock_outline, size: 18),
            title: Text('${d['nombre']}', overflow: TextOverflow.ellipsis),
            subtitle: const Text('Del arribo', style: TextStyle(fontSize: 11)),
          ),
        for (var i = 0; i < _newDocs.length; i++)
          ListTile(
            dense: true,
            leading: const Icon(Icons.insert_drive_file_outlined, size: 18),
            title: Text('${_newDocs[i]['nombre']}', overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete, size: 18),
              onPressed: () => setState(() => _newDocs.removeAt(i)),
            ),
          ),
        if (_inheritedDocs.isEmpty && _newDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Sin documentos.', style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}