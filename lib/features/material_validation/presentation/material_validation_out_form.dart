import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gaso_tenant_app/core/widgets/lists/tiles.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/forms/controllers_manager.dart';
import 'package:gaso_tenant_app/core/forms/photo_manager.dart';
import 'package:gaso_tenant_app/core/forms/signature_validator.dart';
import 'package:gaso_tenant_app/core/validators/form_validators.dart';
import 'package:gaso_tenant_app/core/widgets/forms/photo_upload.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/forms/signatures.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/widgets/media/visual_dialogs.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/services/s3_service.dart';
import 'package:gaso_tenant_app/core/services/qr_service.dart';
import 'package:gaso_tenant_app/core/services/location_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/services/date_time_picker_service.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/helpers/regexp_helper.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/helpers/generators_helper.dart';
import 'package:gaso_tenant_app/core/helpers/input_formatters_helper.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';
import 'package:gaso_tenant_app/features/material_validation/data/material_validation_service.dart';

/// Form de **salida derivada** (OutDerived) de Validación de Material.
///
/// El material se hereda de la entrada [materialIn] y va **read-only**: solo se
/// capturan los datos generales de la salida. Al enviar se genera `folioOut`,
/// se renderiza y sube su QR (QR directo móvil) y se hace
/// `POST /out?directQR=true` (contrato §3.3/§4.3). El candado `ALREADY_EXTENDED`
/// ya lo validó `verify-folio` antes de llegar aquí; el 409 es el backstop.
class MaterialValidationOutForm extends StatefulWidget {
  final MaterialValidation? materialIn;
  const MaterialValidationOutForm({super.key, required this.materialIn});

  @override
  State<MaterialValidationOutForm> createState() => _MaterialValidationOutFormState();
}

class _MaterialValidationOutFormState extends State<MaterialValidationOutForm> {
  late final SessionUser _sessionUser;
  late final MaterialValidation _in;
  bool _sessionReady = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final MaterialValidationService _service = MaterialValidationService();
  final S3Service _s3Service = S3Service();
  final QrService _qrService = QrService();
  final LocationService _locationService = LocationService();
  final ControllersManager _controllers = ControllersManager();
  late final PhotoManager _photoManager;

  final SignatureController _firmaASP = SignatureController(penStrokeWidth: 2, penColor: Colors.black, disabled: true);

  DateTime _fechaForm = DateTime.now();
  List<PhotoField> _photoFields = [];
  String _watermark = '';

  // Documentos heredados del IN (read-only) + nuevos que agregue el usuario.
  List<Map<String, dynamic>> _inheritedDocs = [];
  final List<Map<String, dynamic>> _newDocs = [];

  late final String _photosFolder;
  final String _formattedDate = getCurrentFormattedDate('yyyyMMdd:hhmmss');

  bool _isBuilding = true;
  bool _isSubmitting = false;

  String _deepLink(String folio) => 'gasosaas://mv/$folio';

  @override
  void initState() {
    super.initState();
    final session = AuthContext.instance.current;
    if (session == null || session.user.id == null || widget.materialIn == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MessengerService.error('No se pudo cargar la entrada de origen.');
        Navigator.pop(context);
      });
      return;
    }
    _sessionUser = session;
    _in = widget.materialIn!;
    _sessionReady = true;
    // Llave base COMPLETA con folder de entorno (Qa/|Pr/), igual que el alta.
    _photosFolder = '${Config.s3Folder}/${_sessionUser.tenant.slug}/material_validation/';
    _photoManager = PhotoManager(s3Service: _s3Service, userId: _sessionUser.user.id!, photosFolder: _photosFolder);
    _loadData();
  }

  @override
  void dispose() {
    _controllers.dispose();
    _firmaASP.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      _inheritedDocs = _in.documentos
          .whereType<Map>()
          .map((d) => {'name': d['name']?.toString() ?? '', 'file': d['file']?.toString() ?? ''})
          .where((d) => (d['file'] as String).isNotEmpty)
          .toList();
      _photoFields = [
        PhotoField('foto_transporte', 'Transporte (Vehículo)'),
        PhotoField('foto_placas', 'Placas del transporte'),
        PhotoField('foto_material_transporte', 'Material en transporte'),
      ];
      final location = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _watermark = '${getFormattedDate(_fechaForm, 'dd/MM/yyyy')}\n${location?.latitude},${location?.longitude}';
        });
      }
    } catch (e) {
      DebugLog.error('OutForm _loadData: $e');
      MessengerService.error('Ocurrió un error al preparar el formulario.');
    } finally {
      if (mounted) setState(() => _isBuilding = false);
    }
  }

  Future<void> _pickFecha() async {
    final fecha = await DateTimePickerService.pickFechaSola(context, currentValue: _fechaForm);
    if (fecha != null) setState(() => _fechaForm = fecha);
  }

  bool _validateSignature() {
    if (!SignatureValidator.isSigned(_firmaASP, null)) {
      MessengerService.info('La firma es obligatoria.');
      return false;
    }
    if (!SignatureValidator.isValid(_firmaASP, null)) {
      MessengerService.info('La firma debe ser un poco más compleja.');
      return false;
    }
    return true;
  }

  Future<void> _addDocumento() async {
    final nameController = TextEditingController();
    String? localPath;
    String? mimeType;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Agregar documento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                decoration: inputDec('Nombre del documento'),
                inputFormatters: [LengthLimitingTextInputFormatter(80), FilteringTextInputFormatter.deny(notUsedExp)],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text(
                  localPath != null ? localPath!.split('/').last : 'Seleccionar archivo',
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () async {
                  final picked = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                  );
                  if (picked != null && picked.files.single.path != null) {
                    if (picked.files.single.size > 5 * 1024 * 1024) {
                      return MessengerService.info('El archivo supera el máximo de 5 MB.');
                    }
                    final ext = picked.files.single.extension?.toLowerCase() ?? '';
                    setDlg(() {
                      localPath = picked.files.single.path;
                      mimeType = ext == 'pdf' ? 'application/pdf' : 'image/jpeg';
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return MessengerService.info('El nombre es obligatorio.');
                if (localPath == null) return MessengerService.info('Selecciona un archivo.');
                Navigator.pop(ctx, true);
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      setState(
        () => _newDocs.add({
          'name': nameController.text.trim(),
          'localPath': localPath!,
          'mimeType': mimeType ?? 'image/jpeg',
          'file': '',
        }),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => nameController.dispose());
  }

  Future<bool> _uploadNewDocs() async {
    for (int i = 0; i < _newDocs.length; i++) {
      final doc = _newDocs[i];
      final lp = doc['localPath'] as String?;
      if (lp == null || lp.isEmpty) continue;
      try {
        final bytes = await File(lp).readAsBytes();
        final mime = doc['mimeType'] as String? ?? 'image/jpeg';
        final ext = mime.contains('pdf') ? 'pdf' : 'jpg';
        final path = '${_photosFolder}docs/${_sessionUser.user.id}/$_formattedDate-out-$i.$ext';
        final url = await _s3Service.uploadU8LToS3(bytes, path, mime);
        if (url == null) {
          MessengerService.error('Error al subir el documento "${doc['name']}".');
          return false;
        }
        _newDocs[i]['file'] = path; // guarda la LLAVE completa
      } catch (e) {
        DebugLog.error('OutForm subir doc: $e');
        MessengerService.error('Error inesperado al subir "${doc['name']}".');
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (!hasConnection(context)) return;
    if (!_formKey.currentState!.validate()) return MessengerService.info('Corrige los campos marcados.');
    if (!_validateSignature()) return;
    if (!_photoManager.validateRequiredPhotos(_photoFields)) {
      final missing = _photoManager.getMissingPhotos(_photoFields);
      return MessengerService.info('Faltan fotos: ${missing.join(", ")}');
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar salida'),
        content: const Text('Se generará la salida de material a partir de esta entrada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (mounted) setState(() => _isSubmitting = true);
    try {
      final folioOut = getFolio(_sessionUser.user.id, 'VMS-${_in.idProyecto}${_in.idTipoMaterial}');

      final firmaB64 = await SignatureValidator.encode(_firmaASP, false, existing: null);
      if (firmaB64 == null) {
        MessengerService.error('Error al procesar la firma.');
        return;
      }

      // QR de la salida (deep link) → S3.
      final qrPath = '$_photosFolder${_sessionUser.user.id}/$folioOut.png';
      final qrBytes = await _qrService.generateQrBytes(_deepLink(folioOut));
      final qrUrl = await _s3Service.uploadU8LToS3(qrBytes, qrPath, 'image/png');
      if (qrUrl == null) {
        MessengerService.error('Ocurrió un error al subir el QR a S3.');
        return;
      }

      // 3 fotos de transporte → S3.
      final photos = await _photoManager.uploadPhotos(_photoFields, _formattedDate);
      if (!photos.isSuccess) {
        MessengerService.error('Error al subir imágenes: ${photos.errors.join(", ")}');
        return;
      }

      // Documentos nuevos (opcional) → S3.
      if (_newDocs.isNotEmpty && !await _uploadNewDocs()) return;
      final allDocs = [
        ..._inheritedDocs.map((d) => {'name': d['name'], 'file': d['file']}),
        ..._newDocs.map((d) => {'name': d['name'], 'file': d['file']}),
      ];

      final notas = _controllers.getValue('notas');
      final payload = <String, dynamic>{
        'folioIn': _in.folio,
        'folioOut': folioOut,
        'qr': qrPath,
        'fecha': getFormattedDate(_fechaForm, 'yyyy-MM-dd'),
        'aspNombre': _controllers.getValue('aspNombre'),
        'firmaBase64': firmaB64,
        'nombreContacto': _controllers.getValue('nombreContacto'),
        'placasTransporte': _controllers.getValue('placasTransporte'),
        'fotoTransporte': photos.urls['foto_transporte'],
        'fotoPlacas': photos.urls['foto_placas'],
        'fotoMaterialTransporte': photos.urls['foto_material_transporte'],
        if (notas.isNotEmpty) 'notas': notas,
        if (allDocs.isNotEmpty) 'materialDocumentos': jsonEncode(allDocs),
      };

      final res = await _service.createOut(payload);
      if (!mounted) return;
      if (res.success) {
        _qrService.showQRDialog(
          context,
          _deepLink(folioOut),
          () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.materialValidationList,
            (r) => r.settings.name == AppRoutes.home,
          ),
          label: folioOut,
        );
      } else if (res.statusCode == 409) {
        MessengerService.info('Esta entrada ya tiene salida.');
        Navigator.pop(context);
      } else {
        MessengerService.error(res.message);
      }
    } catch (e) {
      DebugLog.error('OutForm _submit: $e');
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
    return Scaffold(
      appBar: const AppBarHeader('Material de Salida'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isBuilding) return const Center(child: CircularProgressIndicator());
          return SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16,
                  children: [
                    _originCard(),
                    _originMaterial(),
                    SectionTitle(
                      'Datos de la salida',
                      subtitle: 'El material se hereda de la entrada y no se edita aquí',
                    ),
                    _captureFields(),
                    SectionTitle('Fotografías de transporte'),
                    PhotosGrid(context, _photoFields, watermark: _watermark),
                    ExpansionListTile(
                      'Documentos',
                      '(Opcional) evidencias o archivos de la salida.',
                      _addDocumento,
                      children: [
                        for (int i = 0; i < _newDocs.length; i++)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.attach_file, size: 20),
                            title: Text('${_newDocs[i]['name']}', overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              (_newDocs[i]['localPath'] as String? ?? '').split('/').last,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => setState(() => _newDocs.removeAt(i)),
                            ),
                          ),
                      ],
                    ),
                    _isSubmitting
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.logout),
                                  onPressed: _submit,
                                  label: const Text('GENERAR SALIDA'),
                                ),
                              ),
                            ],
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

  Widget _originCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          spacing: 12,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.login, color: colorScheme.onPrimaryContainer),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _in.proyecto,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(_in.folio, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  const Text('Entrada de origen'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _originMaterial() {
    final carrier = _in.idCarrier != 4 ? _in.carrier : (_in.otroCarrier ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Material de la entrada'),
        const SizedBox(height: 4),
        LabelValue('Tipo de material', _in.tipoMaterial),
        LabelValue('Id sitio', _in.idSitio),
        LabelValue('Nombre sitio', _in.nombreSitio),
        LabelValue('Cuenta / Cliente', _in.cuentaCliente),
        LabelValue('Carrier', carrier),
        LabelValue('Almacén destino', _in.almacenDestino),
        LabelValue('Región', 'R ${_in.idRegion}'),
        LabelValue('Total de piezas', '${_in.totalPiezas}'),
        if (_in.numTarimas > 0) LabelValue('Tarimas', '${_in.numTarimas}'),
        Wrap(
          spacing: 8,
          children: [
            if (_in.tarimas.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.view_module_outlined, size: 16),
                label: const Text('Ver tarimas'),
                onPressed: () => showImagesDialog(context, images: imagesFromMap(_in.tarimas)),
              ),
            if (_inheritedDocs.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.folder_open, size: 16),
                label: Text('Documentos (${_inheritedDocs.length})'),
                onPressed: _showInheritedDocs,
              ),
          ],
        ),
        if (_in.piezasMotivo.isNotEmpty) _piezas('Piezas por motivo', _in.piezasMotivo),
        if (_in.piezasEstadoF.isNotEmpty) _piezas('Piezas por estado físico', _in.piezasEstadoF),
      ],
    );
  }

  Widget _piezas(String title, List<dynamic> piezas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        SectionTitle(title),
        for (final r in piezas) LabelValue('${r['clt'] ?? r['cl'] ?? '-'}', '${r['pzs'] ?? '-'}'),
      ],
    );
  }

  void _showInheritedDocs() {
    bool isPdf(String? f) => f?.toLowerCase().contains('.pdf') ?? false;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Documentos heredados'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final doc in _inheritedDocs)
                ListTile(
                  dense: true,
                  leading: Icon(isPdf(doc['file'] as String?) ? Icons.picture_as_pdf : Icons.image, size: 20),
                  title: Text('${doc['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    final raw = (doc['file'] as String?) ?? '';
                    if (raw.isEmpty) return;
                    final url = solvedUrl(raw);
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

  Widget _captureFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
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
          controller: _controllers.get('aspNombre'),
          decoration: inputDec('Nombre ASP'),
          validator: (v) => FormValidators.required(v, 'nombre asp'),
          inputFormatters: [LengthLimitingTextInputFormatter(50), FilteringTextInputFormatter.deny(notUsedExp)],
        ),
        SignatureCard('Firma ASP', _firmaASP),
        TextFormField(
          controller: _controllers.get('nombreContacto'),
          decoration: inputDec('Nombre del contacto'),
          validator: (v) => FormValidators.required(v, 'contacto'),
          inputFormatters: [LengthLimitingTextInputFormatter(50), FilteringTextInputFormatter.deny(notUsedExp)],
        ),
        TextFormField(
          controller: _controllers.get('placasTransporte'),
          decoration: inputDec('Placas del transporte'),
          validator: (v) => FormValidators.required(v, 'placas'),
          inputFormatters: [
            UpperCaseTextFormatter(),
            LengthLimitingTextInputFormatter(20),
            FilteringTextInputFormatter.allow(lngExp),
          ],
        ),
        TextFormField(
          controller: _controllers.get('notas'),
          decoration: inputDec('Observaciones y notas'),
          minLines: 3,
          maxLines: 5,
          inputFormatters: [LengthLimitingTextInputFormatter(300), FilteringTextInputFormatter.deny(notUsedExp)],
        ),
      ],
    );
  }
}
