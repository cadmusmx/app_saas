import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/forms/signature_validator.dart';
import 'package:gaso_tenant_app/core/forms/controllers_manager.dart';
import 'package:gaso_tenant_app/core/forms/draft_manager.dart';
import 'package:gaso_tenant_app/core/forms/photo_manager.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/validators/form_validators.dart';
import 'package:gaso_tenant_app/core/widgets/forms/photo_upload.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/forms/dialogs.dart';
import 'package:gaso_tenant_app/core/widgets/lists/tiles.dart';
import 'package:gaso_tenant_app/core/widgets/forms/signatures.dart';
import 'package:gaso_tenant_app/core/widgets/info/info_letter.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';
import 'package:gaso_tenant_app/core/storage/preferences.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/extensions/extensions.dart';
import 'package:gaso_tenant_app/core/services/s3_service.dart';
import 'package:gaso_tenant_app/core/services/date_time_picker_service.dart';
import 'package:gaso_tenant_app/core/services/qr_service.dart';
import 'package:gaso_tenant_app/core/services/location_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/helpers/regexp_helper.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/helpers/generators_helper.dart';
import 'package:gaso_tenant_app/core/helpers/input_formatters_helper.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_catalogs.dart';
import 'package:gaso_tenant_app/features/material_validation/data/material_validation_service.dart';
import 'package:gaso_tenant_app/features/material_validation/data/material_catalogs_service.dart';
import 'package:gaso_tenant_app/features/material_validation/presentation/material_validation_info.dart';

class MaterialValidationForm extends StatefulWidget {
  final MaterialValidation? materialValidation;
  const MaterialValidationForm({super.key, this.materialValidation});

  @override
  State<MaterialValidationForm> createState() => _MaterialValidationFormState();
}

class _MaterialValidationFormState extends State<MaterialValidationForm> {
  late final SessionUser _sessionUser;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final MaterialValidationService _materialValidationService = MaterialValidationService();
  final S3Service _s3Service = S3Service();
  final Preferences _preferences = Preferences();
  final LocationService _locationService = LocationService();
  MaterialCatalogs? _catalogs;
  final QrService _qrService = QrService();
  final _controllers = ControllersManager();
  late final PhotoManager _photoManager;
  late final DraftManager _draftManager;

  bool _es = true;
  bool _esChanged = false;
  DateTime _fechaForm = DateTime.now();
  String? _proyectoForm;
  String? _destinoForm;
  String? _tipoMaterialForm;
  String? _idCarrierForm;
  String? _regionForm;
  List<Map<String, String>> _piezasMotivo = []; // listas de uso general
  List<Map<String, String>> _piezasEstadoF = [];
  List<Map<String, String>> _documentos = [];
  final List<int> _piezasMotivoDel = []; // listas para registros a borrar
  final List<int> _piezasEstadoFDel = [];
  final List<int> _documentosDel = [];
  bool _tarimasForm = false;
  List<PhotoField> _pfTarimas = [];
  String _watermark = '';

  final _firmaASP = SignatureController(penStrokeWidth: 2, penColor: Colors.black, disabled: true);
  Uint8List? _existingFASP;

  List<PhotoField> _photoFields = [];
  final Map<String, String> _photoUrls = {};
  late final String _photosFolder;
  final String _formattedDate = getCurrentFormattedDate('yyyyMMdd:hhmmss');

  bool _isSubmitting = false;
  bool _isEdition = false;
  MaterialValidation? _material;
  bool _isBuilding = true;
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    final session = AuthContext.instance.current;
    if (session != null && session.user.id != null) {
      _sessionUser = session;
      _sessionReady = true;
      _photosFolder = '${_sessionUser.tenant.slug}/material_validation/';
      _draftManager = DraftManager('material_validation_draft');
      _photoManager = PhotoManager(s3Service: _s3Service, userId: _sessionUser.user.id!, photosFolder: _photosFolder);
      _loadData();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MessengerService.info('Ocurrió un error al obtener sus datos');
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    }
  }

  @override
  void dispose() {
    _controllers.dispose();
    _firmaASP.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _preferences.init();
      String? materialDescargadoFotoUrl;
      String? materialEnTransporteFotoUrl;
      String? placasFotoUrl;
      String? transporteFotoUrl;
      if (widget.materialValidation != null && mounted) {
        setState(() {
          _isEdition = true;
          _material = widget.materialValidation;
          _es = _material?.es ?? _es;
          _proyectoForm = (_material?.idProyecto).toNullableStr();
          _tipoMaterialForm = (_material?.idTipoMaterial).toNullableStr();
          _idCarrierForm = (_material?.idCarrier).toNullableStr();
          _existingFASP = base64Decode(_material!.aspFirma);
          _fechaForm = parseDate((_material?.fecha).toClearStr());
          _regionForm = (_material?.idRegion).toNullableStr();
          _destinoForm = (_material?.idAlmacenDestino).toNullableStr();
          materialDescargadoFotoUrl = _material?.materialDescargadoFoto;
          materialEnTransporteFotoUrl = _material?.materialEnTransporteFoto;
          placasFotoUrl = _material?.placasFoto;
          transporteFotoUrl = _material?.transporteFoto;
          _piezasEstadoF = (_material?.piezasEstadoF ?? [])
              .whereType<Map>()
              .map((pef) => pef.map((key, value) => MapEntry(key.toString(), value.toString())))
              .toList();
          _piezasMotivo = (_material?.piezasMotivo ?? [])
              .whereType<Map>()
              .map((pm) => pm.map((key, value) => MapEntry(key.toString(), value.toString())))
              .toList();
          _documentos = (_material?.documentos ?? [])
              .whereType<Map>()
              .map((d) => d.map((k, v) => MapEntry(k.toString(), v.toString())))
              .toList();
          _tarimasForm = _material != null && _material!.numTarimas > 0;
        });
        _controllers.loadFromMap({
          'nombreSitio': (_material?.nombreSitio).toClearStr(),
          'idSitio': (_material?.idSitio).toClearStr(),
          'cuentaCliente': (_material?.cuentaCliente).toClearStr(),
          'aspNombre': (_material?.aspNombre).toClearStr(),
          'nombreContacto': (_material?.nombreContacto).toClearStr(),
          'totalPiezas': (_material?.totalPiezas).toClearStr(),
          'placasTransporte': (_material?.placasTransporte).toClearStr(),
          'notas': (_material?.notas).toClearStr(),
        });
        if (_material?.tarimas != null && mounted) {
          setState(() {
            _pfTarimas = _material!.tarimas.entries
                .map((e) => PhotoField(e.key, snakeToTitle(e.key), e.value))
                .toList();
          });
        }
      } else if (mounted) {
        setState(() => _regionForm = _sessionUser.user.region?.toString());
        await _resolveOperationType();
      }
      final location = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _updatePhotoFields(
            transporteUrl: transporteFotoUrl,
            placasUrl: placasFotoUrl,
            materialTransporteUrl: materialEnTransporteFotoUrl,
            descargadoUrl: materialDescargadoFotoUrl,
          );
          _watermark = '${getFormattedDate(_fechaForm, 'dd/MM/yyyy')}\n${location?.latitude},${location?.longitude}';
          if (_isEdition) {
            _photoUrls.clear();
            for (var entry in _photoFields) {
              _photoUrls[entry.key] = entry.url;
            }
          }
        });
      }
      // Catálogos: 1 request (6 GET -> /catalogs), cacheado por tenant. El await
      // elimina el race del constructor async y el Future.delayed(2s) legacy.
      _catalogs = await MaterialCatalogsCache.instance.load();
    } catch (e) {
      DebugLog.error('Error: $e');
      MessengerService.error('Ocurrió un error al obtener los datos requeridos');
    } finally {
      if (mounted) setState(() => _isBuilding = false);
      if (_isEdition) {
        if (_tarimasForm) {
          _controllers.setValue('numTarimas', (_material?.numTarimas).toClearStr());
        }
        if (_idCarrierForm == '4') {
          _controllers.setValue('carrier', (_material?.carrier).toClearStr());
        }
      }
    }
  }

  Future<void> _resolveOperationType() async {
    final pref = _preferences.vmES;
    if (pref != null) {
      setState(() => _es = pref);
    }
  }

  Future<void> _toggleES() async {
    if (!hasConnection(context)) return;
    try {
      final response = await _materialValidationService.verifyLinkedFolio(_material!.folio);
      if (!response.success) {
        return MessengerService.error(response.message);
      }
      if (response.data == true) {
        return MessengerService.info(
          'No se puede cambiar el tipo porque el folio ya está vinculado a un proceso de validación.',
        );
      }
      await _showConfirmationESDialog();
    } catch (e) {
      DebugLog.error('Error toggleES: $e');
      MessengerService.error('Error al verificar el folio');
    }
  }

  Future<void> _showConfirmationESDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar tipo'),
        content: RichText(
          text: TextSpan(
            style: Theme.of(ctx).textTheme.bodyMedium,
            children: [
              const TextSpan(text: 'Se cambiará de '),
              TextSpan(
                text: _es ? 'ENTRADA' : 'SALIDA',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' a '),
              TextSpan(
                text: _es ? 'SALIDA' : 'ENTRADA',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '. Se regenerará el folio y el QR.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _es = !_es;
      _esChanged = true;
      _updatePhotoFields();
    });
  }

  void _updatePhotoFields({
    String? transporteUrl,
    String? placasUrl,
    String? materialTransporteUrl,
    String? descargadoUrl,
  }) {
    // Preservar URLs/paths de los PhotoFields actuales si no se pasan parámetros
    final existing = {for (var pf in _photoFields) pf.key: pf};

    String resolve(String key, String? paramUrl) {
      if (paramUrl != null) return paramUrl;
      return existing[key]?.url ?? '';
    }

    _photoFields = [
      PhotoField('foto_transporte', 'Transporte (Vehículo)', resolve('foto_transporte', transporteUrl)),
      PhotoField('foto_placas', 'Placas del transporte', resolve('foto_placas', placasUrl)),
      PhotoField(
        'foto_material_transporte',
        'Material en transporte',
        resolve('foto_material_transporte', materialTransporteUrl),
      ),
    ];
    if (_es) {
      _photoFields.add(PhotoField('foto_descargado', 'Material descargado', resolve('foto_descargado', descargadoUrl)));
    }
  }

  Future<void> _pickFecha() async {
    final fecha = await DateTimePickerService.pickFechaSola(context, currentValue: _fechaForm);
    if (fecha != null) setState(() => _fechaForm = fecha);
  }

  bool _validateSignatures() {
    if (!SignatureValidator.isSigned(_firmaASP, _existingFASP)) {
      MessengerService.info('La firma es obligatoria.');
      return false;
    }
    if (!SignatureValidator.isValid(_firmaASP, _existingFASP)) {
      MessengerService.info('La firma debe ser un poco más compleja.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!hasConnection(context)) return;
    if (!_formKey.currentState!.validate()) return MessengerService.info('Corrige los campos marcados.');
    if (!_validateSignatures()) return;
    if (!_tarimasForm && _piezasMotivo.isEmpty && _piezasEstadoF.isEmpty && _documentos.isEmpty) {
      return MessengerService.info('Debe registrar al menos una de las tres opciones: piezas, documentos o tarimas');
    }
    if (mounted) setState(() => _isSubmitting = true);
    try {
      if (_isEdition) {
        final result = await _handleEditForm();
        if (!mounted) return;
        if (result != null) {
          if (result.isNotEmpty) {
            // Hubo cambio de E/S, mostrar nuevo QR
            _preferences.vmES = _es;
            _qrService.showQRDialog(context, result, () => Navigator.pushReplacementNamed(context, AppRoutes.home));
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
        }
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar validación'),
            content: RichText(
              text: TextSpan(
                style: Theme.of(ctx).textTheme.bodyMedium,
                children: [
                  const TextSpan(text: 'Confirme la validación de '),
                  TextSpan(
                    text: _es ? 'ENTRADA' : 'SALIDA',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' de material'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
            ],
          ),
        );
        if (confirmed != true) return;

        final folio = getFolio(_sessionUser.user.id, 'VM${_es ? 'E' : 'S'}-$_proyectoForm$_tipoMaterialForm');
        final success = await _handleNewForm(folio);
        if (!mounted) return;
        if (success) {
          _preferences.vmES = _es;
          _qrService.showQRDialog(context, folio, () => Navigator.pushReplacementNamed(context, AppRoutes.home));
        }
      }
    } catch (e) {
      DebugLog.error('Error _submit: $e');
      MessengerService.error('Ha ocurrido un error inesperado.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _handleNewForm(String folio) async {
    final String? aspB64 = await SignatureValidator.encode(_firmaASP, _isEdition, existing: _existingFASP);
    if (aspB64 == null) {
      MessengerService.error('Error al procesar la firma.');
      return false;
    }
    if (!_photoManager.validateRequiredPhotos(_photoFields, isEdition: _isEdition)) {
      final missing = _photoManager.getMissingPhotos(_photoFields, isEdition: _isEdition);
      MessengerService.info('Faltan fotos: ${missing.join(", ")}');
      return false;
    }
    if (_tarimasForm && !_photoManager.validateRequiredPhotos(_pfTarimas, isEdition: _isEdition)) {
      final missing = _photoManager.getMissingPhotos(_pfTarimas);
      MessengerService.info('Faltan fotos de tarimas: ${missing.join(", ")}');
      return false;
    }

    // subir el QR del folio a S3
    final urlQR = 'appgaso://mv/$folio';
    final qrBytes = await _qrService.generateQrBytes(urlQR);
    final String qrPath = '$_photosFolder${_sessionUser.user.id}/$folio.png';
    final url = await _s3Service.uploadU8LToS3(qrBytes, qrPath, 'image/png');
    if (url == null) {
      MessengerService.error('Ocurrió un error al subir el QR a S3.');
      return false;
    }

    // subir reporte fotográfico
    final photosResult = await _photoManager.uploadPhotos(_photoFields, _formattedDate);
    if (!photosResult.isSuccess) {
      MessengerService.error('Error al subir imágenes: ${photosResult.errors.join(", ")}');
      return false;
    }
    Map<String, String?> tarimasUrls = {};
    if (_tarimasForm) {
      final tarimasResult = await _photoManager.uploadPhotos(_pfTarimas, _formattedDate);
      if (!tarimasResult.isSuccess) {
        MessengerService.error('Error al subir tarimas: ${tarimasResult.errors.join(", ")}');
        return false;
      }
      tarimasUrls = tarimasResult.urls;
    }
    if (_documentos.isNotEmpty) {
      final docsOk = await _uploadPendingDocumentos();
      if (!docsOk) return false;
    }
    final payload = _buildPayload();
    payload['es'] = _es; // el server ya no lo infiere del método; va en el body
    payload['folio'] = folio;
    payload['firmaBase64'] = aspB64;
    payload['qr'] = qrPath;
    for (var url in photosResult.urls.entries) {
      String photoKey = snakeToCamel(url.key);
      payload[photoKey] = url.value;
    }
    if (_tarimasForm) {
      payload['tarimas'] = jsonEncode(tarimasUrls);
      payload['numTarimas'] = _controllers.getValue('numTarimas');
    }
    final success = await _handleRequest(
      () => _materialValidationService.createRecord(payload),
      '${_es ? 'Entrada' : 'Salida'} de material creada exitosamente.',
    );
    return success;
  }

  Future<String?> _handleEditForm() async {
    final newPhotoUrls = await _photoManager.processEditedPhotos(_photoFields, _photoUrls, _formattedDate);
    if (!newPhotoUrls.isSuccess) {
      final length = newPhotoUrls.errors.length;
      MessengerService.error(newPhotoUrls.errors.getRange(0, length > 5 ? 5 : length).join("\n"));
      return null;
    }
    final formData = _buildPayloadChanges();
    // Cambio de tipo E/S: regenerar folio y QR
    if (_esChanged) {
      final newFolio = getFolio(_sessionUser.user.id, 'VM${_es ? 'E' : 'S'}-$_proyectoForm$_tipoMaterialForm');

      // Generar y subir nuevo QR
      final urlQR = 'appgaso://mv/$newFolio';
      final qrBytes = await _qrService.generateQrBytes(urlQR);
      final newQrPath = '$_photosFolder${_sessionUser.user.id}/$newFolio.png';
      final qrUrl = await _s3Service.uploadU8LToS3(qrBytes, newQrPath, 'image/png');
      if (qrUrl == null) {
        MessengerService.error('Error al subir el nuevo QR.');
        return null;
      }

      // Eliminar QR anterior
      if (_material!.qr.isNotEmpty) {
        await _s3Service.deleteFromS3(_material!.qr);
      }

      formData['folio'] = newFolio;
      formData['qr'] = newQrPath;
      formData['es'] = _es;
    }

    for (var entry in newPhotoUrls.urls.entries) {
      if (_photoUrls[entry.key] != entry.value) {
        String fotoKey = snakeToCamel(entry.key);
        formData[fotoKey] = entry.value;
      }
    }
    if (_tarimasForm && _material?.tarimas != null) {
      final tarimasResult = await _photoManager.processEditedPhotos(_pfTarimas, _material!.tarimas, _formattedDate);
      if (tarimasResult.isSuccess) {
        for (var entry in tarimasResult.urls.entries) {
          if (_material!.tarimas[entry.key] != entry.value) {
            _material!.tarimas[entry.key] = entry.value;
          }
        }
        formData['tarimas'] = jsonEncode(_material!.tarimas);
        formData['numTarimas'] = _controllers.getValue('numTarimas');
      } else {
        final length = tarimasResult.errors.length;
        MessengerService.error(tarimasResult.errors.getRange(0, length > 5 ? 5 : length).join("\n"));
        return null;
      }
    }
    bool docsChanged =
        _documentos.any((d) => d['localPath'] != null) ||
        _documentosDel.isNotEmpty ||
        _documentos.any((d) => d['edt'] != null);
    if (docsChanged) {
      if (_documentos.any((d) => d['localPath'] != null)) {
        final docsOk = await _uploadPendingDocumentos();
        if (!docsOk) return null;
      }
      final docsLimpio = _documentos.map((d) => {'name': d['name']!, 'file': d['file']!}).toList();
      formData['materialDocumentos'] = jsonEncode(docsLimpio);
    }
    if (formData.isEmpty) {
      MessengerService.info('No se hicieron cambios.');
      return null;
    }
    final success = await _handleRequest(
      () => _materialValidationService.updateRecord(_material!.folio, formData),
      '${_es ? 'Entrada' : 'Salida'} de material actualizada exitosamente.',
    );
    if (!success) return null;
    return _esChanged ? formData['folio'] as String? : '';
  }

  Future<bool> _handleRequest<T>(Future<ServiceResponse<T>> Function() action, String successMsg) async {
    final response = await action();
    if (response.success) {
      MessengerService.success(successMsg);
    } else {
      MessengerService.error(response.message);
    }
    return response.success;
  }

  Future<void> _saveDraft() async {
    await _draftManager.saveDraft(_buildPayload());
  }

  Future<void> _loadDraft() async {
    final draft = await _draftManager.loadDraft();
    if (draft == null) return;
    _controllers.loadFromMap(draft);
    setState(() {
      _proyectoForm = draft['idProyecto'] ?? _proyectoForm;
      _tipoMaterialForm = draft['idTipoMaterial'] ?? _tipoMaterialForm;
      _idCarrierForm = draft['idCarrier'] ?? _idCarrierForm;
      _regionForm = draft['idRegion'] ?? _regionForm;
      _destinoForm = draft['idAlmacenDestino'] ?? '';
    });
  }

  Map<String, dynamic> _buildPayload() {
    final data = _controllers.toMap();
    final docsLimpio = _documentos.map((d) => {'name': d['name']!, 'file': d['file']!}).toList();
    return {
      "idProyecto": _proyectoForm,
      "idTipoMaterial": _tipoMaterialForm,
      "fecha": _fechaForm.toIso8601String(),
      "idRegion": _regionForm,
      "idCarrier": _idCarrierForm,
      "idAlmacenDestino": _destinoForm,
      "piezasMotivo": _piezasMotivo,
      "piezasEstadoF": _piezasEstadoF,
      "materialDocumentos": jsonEncode(docsLimpio),
      ...data,
      if (_tarimasForm) "numTarimas": _controllers.getValue('numTarimas'),
      if (_tarimasForm) "tarimas": _controllers.getValue('numTarimas'),
    };
  }

  Map<String, dynamic> _buildPayloadChanges() {
    final currentData = _controllers.toMap();
    Map<String, List<String?>> values = {
      "idProyecto": [_proyectoForm, _material?.idProyecto.toClearStr()],
      "idTipoMaterial": [_tipoMaterialForm, _material?.idTipoMaterial.toClearStr()],
      "nombreSitio": [currentData['nombreSitio'], _material?.nombreSitio],
      "idSitio": [currentData['idSitio'], _material?.idSitio],
      "cuentaCliente": [currentData['cuentaCliente'], _material?.cuentaCliente],
      "fecha": [_fechaForm.toIso8601String(), _material?.fecha],
      "aspNombre": [currentData['aspNombre'], _material?.aspNombre],
      "nombreContacto": [currentData['nombreContacto'], _material?.nombreContacto],
      'idCarrier': [_idCarrierForm, _material?.idCarrier.toClearStr()],
      "carrier": [currentData['carrier'], _material?.carrier],
      "idRegion": [_regionForm, '${_material?.idRegion}'],
      "idAlmacenDestino": [_destinoForm, _material?.almacenDestino],
      "totalPiezas": [currentData['totalPiezas'], '${_material?.totalPiezas}'],
      "placasTransporte": [currentData['placasTransporte'], _material?.placasTransporte],
      "notas": [currentData['notas'], _material?.notas],
    };
    final Map<String, dynamic> payload = {};
    for (var entry in values.entries) {
      if (entry.value[0] != entry.value[1]) payload.addAll({entry.key: entry.value[0]});
    }
    // Formas exactas del contrato. `edt`/`clt` son marcadores internos del cliente.
    final piezasMotivoAdd = _piezasMotivo
        .where((p) => p['id'] == null)
        .map((p) => {'cl': p['cl'], 'pzs': p['pzs']})
        .toList();
    final piezasEstadoFAdd = _piezasEstadoF
        .where((p) => p['id'] == null)
        .map((p) => {'cl': p['cl'], 'pzs': p['pzs']})
        .toList();
    final piezasMotivoEdit = _piezasMotivo
        .where((p) => p['edt'] != null)
        .map((p) => {'id': int.tryParse(p['id'] ?? ''), 'cl': p['cl'], 'pzs': p['pzs']})
        .toList();
    final piezasEstadoFEdit = _piezasEstadoF
        .where((p) => p['edt'] != null)
        .map((p) => {'id': int.tryParse(p['id'] ?? ''), 'cl': p['cl'], 'pzs': p['pzs']})
        .toList();
    if (piezasMotivoAdd.isNotEmpty) payload['piezasMotivoAdd'] = piezasMotivoAdd;
    if (piezasEstadoFAdd.isNotEmpty) payload['piezasEstadoFAdd'] = piezasEstadoFAdd;
    if (piezasMotivoEdit.isNotEmpty) payload['piezasMotivoEdit'] = piezasMotivoEdit;
    if (piezasEstadoFEdit.isNotEmpty) payload['piezasEstadoFEdit'] = piezasEstadoFEdit;
    if (_piezasMotivoDel.isNotEmpty) payload['piezasMotivoDel'] = _piezasMotivoDel;
    if (_piezasEstadoFDel.isNotEmpty) payload['piezasEstadoFDel'] = _piezasEstadoFDel;
    return payload;
  }

  Future<void> _addEditPiezasMotivo([int? index]) async {
    String? currentClave = index != null ? _piezasMotivo[index]['cl'] : null;
    String? currentPiezas = index != null ? _piezasMotivo[index]['pzs'] : null;
    await _addEditPiezas(
      _piezasMotivo,
      _piezasMotivoDel,
      _catalogs?.reasons ?? const <OptionSL>[],
      'Motivo',
      index,
      currentClave,
      currentPiezas,
    );
  }

  Future<void> _addEditPiezasEstadoF([int? index]) async {
    String? currentClave = index != null ? _piezasEstadoF[index]['cl'] : null;
    String? currentPiezas = index != null ? _piezasEstadoF[index]['pzs'] : null;
    await _addEditPiezas(
      _piezasEstadoF,
      _piezasEstadoFDel,
      _catalogs?.physicalStatus ?? const <OptionSL>[],
      'Estado físico',
      index,
      currentClave,
      currentPiezas,
    );
  }

  /// Permite agregar o editar un registro de piezas
  Future<void> _addEditPiezas(
    List<Map<String, String>> list,
    List<int> delList,
    List<OptionSL> options,
    String label,
    int? index, [
    String? currentClave,
    String? currentPiezas,
  ]) async {
    final optionText = await showOptionTextDialog(
      context,
      'Agregar piezas',
      options,
      label,
      'Piezas por ${label.toLowerCase()}',
      option: currentClave,
      text: currentPiezas ?? '',
    );
    if (optionText != null && optionText.text.isNotEmpty && optionText.option != null) {
      String clave = optionText.option!;
      String piezas = optionText.text;
      if (index != null) {
        if (list[index]['cl'] != clave || list[index]['pzs'] != piezas) {
          setState(() {
            list[index]['cl'] = clave;
            list[index]['pzs'] = piezas;
            if (list[index]['id'] != null) list[index]['edt'] = '1';
          });
        }
      } else {
        final pieza = {'cl': clave, 'pzs': piezas};
        if (delList.isNotEmpty) {
          // si hay piezas borradas
          pieza['id'] = delList[0].toString();
          pieza['edt'] = '1';
          delList.removeAt(0);
        }
        if (mounted) setState(() => list.add(pieza));
      }
    }
  }

  /// Permite eliminar un registro de piezas
  void _removePiezas(int index, List<Map<String, String>> list, List<int> delList) {
    final id = list[index]['id'];
    if (mounted) {
      setState(() {
        if (id != null) {
          final newPIdx = list.indexWhere((p) => p['id'] == null);
          if (newPIdx >= 0) {
            // hay nuevas piezas, asignamos el id de las piezas borradas a estas y marcamos editado
            list[newPIdx]['id'] = id;
            list[newPIdx]['edt'] = '1';
          } else {
            delList.add(int.parse(id));
          }
        }
        list.removeAt(index);
      });
    }
  }

  /// Widget para representar un registro de piezas
  Widget _piezaItem(String clave, String piezas, {required void Function() onEdit, required void Function() onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 16),
      child: Row(
        children: [
          Text('$clave. ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(piezas, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 8),
          IconButton(onPressed: onEdit, icon: Icon(Icons.edit)),
          IconButton(onPressed: onRemove, icon: Icon(Icons.delete)),
        ],
      ),
    );
  }

  Future<void> _addEditDocumento([int? index]) async {
    final nameController = TextEditingController(text: index != null ? _documentos[index]['name'] : '');
    String? localPath;
    String? mimeType;
    String existingFileName = '';
    if (index != null && _documentos[index]['file']!.isNotEmpty) {
      existingFileName = _documentos[index]['file']!.split('/').last;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: Text(index != null ? 'Editar documento' : 'Agregar documento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: inputDec('Nombre del documento'),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(80),
                      FilteringTextInputFormatter.deny(notUsedExp),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      localPath != null
                          ? localPath!.split('/').last
                          : (existingFileName.isNotEmpty ? existingFileName : 'Seleccionar archivo'),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                      );
                      if (picked != null && picked.files.single.path != null) {
                        const maxBytes = 5 * 1024 * 1024; // 10 MB
                        if (picked.files.single.size > maxBytes) {
                          return MessengerService.info('El archivo supera el máximo de 5 MB.');
                        }
                        final ext = picked.files.single.extension?.toLowerCase() ?? '';
                        setDlgState(() {
                          localPath = picked.files.single.path;
                          mimeType = ext == 'pdf' ? 'application/pdf' : 'image/jpeg';
                        });
                      }
                    },
                  ),
                  if (index != null && existingFileName.isNotEmpty && localPath == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Archivo actual: $existingFileName', style: Theme.of(ctx).textTheme.bodySmall),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      MessengerService.info('El nombre del documento es obligatorio.');
                      return;
                    }
                    if (index == null && localPath == null) {
                      MessengerService.info('Selecciona un archivo.');
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final name = nameController.text.trim();
      if (index != null) {
        if (mounted) {
          setState(() {
            if (_documentos[index]['name'] != name) _documentos[index]['name'] = name;
            if (localPath != null) {
              _documentos[index]['localPath'] = localPath!;
              _documentos[index]['mimeType'] = mimeType ?? 'image/jpeg';
              if (_documentos[index]['id'] != null) _documentos[index]['edt'] = '1';
            }
          });
        }
      } else {
        final doc = <String, String>{
          'name': name,
          'file': '',
          if (localPath != null) 'localPath': localPath!,
          if (mimeType != null) 'mimeType': mimeType!,
        };
        if (_documentosDel.isNotEmpty) {
          doc['id'] = _documentosDel[0].toString();
          doc['edt'] = '1';
          _documentosDel.removeAt(0);
        }
        if (mounted) setState(() => _documentos.add(doc));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => nameController.dispose());
  }

  /// Elimina un documento de la lista
  void _removeDocumento(int index) {
    final id = _documentos[index]['id'];
    if (mounted) {
      setState(() {
        if (id != null) _documentosDel.add(int.parse(id));
        _documentos.removeAt(index);
      });
    }
  }

  /// Widget para representar un documento en la lista
  Widget _documentoItem(
    String name,
    String fileRef, {
    required void Function() onEdit,
    required void Function() onRemove,
  }) {
    final isPdf = fileRef.toLowerCase().contains('.pdf');
    final icon = fileRef.isEmpty
        ? Icons.attach_file
        : isPdf
        ? Icons.picture_as_pdf
        : Icons.image;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileRef.isNotEmpty)
                  Text(
                    fileRef.split('/').last,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete)),
        ],
      ),
    );
  }

  /// Sube los documentos pendientes (localPath) a S3 y actualiza las URLs en la lista
  Future<bool> _uploadPendingDocumentos() async {
    for (int i = 0; i < _documentos.length; i++) {
      final doc = _documentos[i];
      final lp = doc['localPath'];
      if (lp == null || lp.isEmpty) continue;
      final oldUrl = doc['file'];
      final oldKey = (oldUrl != null && oldUrl.isNotEmpty)
          ? oldUrl.replaceFirst(Config.s3Url, '') // extrae la key quitando el prefijo del bucket
          : null;
      try {
        final bytes = await File(lp).readAsBytes();
        final mime = doc['mimeType'] ?? 'image/jpeg';
        final ext = mime.contains('pdf') ? 'pdf' : 'jpg';
        final path = '${_photosFolder}docs/${_sessionUser.user.id}/$_formattedDate-$i.$ext';
        final url = await _s3Service.uploadU8LToS3(bytes, path, mime);
        if (url == null) {
          MessengerService.error('Error al subir el documento "${doc['name']}".');
          return false;
        }
        // Elimina el archivo anterior solo si la subida fue exitosa y había un archivo previo
        if (oldKey != null && oldKey.isNotEmpty) {
          await _s3Service.deleteFromS3(oldKey);
        }
        if (mounted) {
          setState(() {
            _documentos[i]['file'] = url;
            _documentos[i].remove('localPath');
            _documentos[i].remove('mimeType');
          });
        }
      } catch (e) {
        DebugLog.error('Error subiendo documento: $e');
        MessengerService.error('Error inesperado al subir "${doc['name']}".');
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Sin sesión válida los `late final` (folder/draft/photoManager) no se inicializan y el post-frame ya navega fuera:
    // muestra loader y no toques nada.
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final colorScheme = Theme.of(context).colorScheme;
    final List<Widget> fields = [
      Row(
        spacing: 8,
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _regionForm,
              items: [
                for (var r in [1, 2, 3, 4, 5, 6, 7, 8, 9]) DropdownMenuItem(value: '$r', child: Text('R $r')),
              ],
              onChanged: (value) => setState(() => _regionForm = value!),
              validator: (v) => FormValidators.required(v, 'región'),
              decoration: inputDec('Región'),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextFormField(
              readOnly: true,
              decoration: inputDec(
                'Fecha',
                flb: FloatingLabelBehavior.always,
                suffix: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickFecha),
              ),
              controller: TextEditingController(text: DateFormat('dd/MM/yyyy').format(_fechaForm)),
              onTap: _pickFecha,
            ),
          ),
        ],
      ),
      Row(
        spacing: 8,
        children: [
          Expanded(
            flex: 1,
            child: FilledButton.icon(
              onPressed: () {
                if (_isEdition && _material?.status == 0) {
                  _toggleES();
                }
                if (!_isEdition) {
                  setState(() {
                    _es = !_es;
                    _updatePhotoFields();
                  });
                }
              },
              label: Text(_es ? 'Entrada' : 'Salida'),
              icon: Icon(_es ? Icons.login : Icons.logout),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
              ),
            ),
          ),
        ],
      ),
    ];
    final List<Widget> generalFields = [
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _proyectoForm,
        items: [
          for (var t in _catalogs?.projects ?? const <OptionSL>[])
            DropdownMenuItem(
              value: t.value,
              child: Text(t.text, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
        ],
        onChanged: (value) => setState(() => _proyectoForm = value!),
        validator: (v) => FormValidators.required(v, 'proyecto'),
        decoration: inputDec('Proyecto'),
      ),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _tipoMaterialForm,
        items: [
          for (var c in _catalogs?.materialTypes ?? const <OptionSL>[])
            DropdownMenuItem(
              value: c.value,
              child: Text(c.text, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
        ],
        onChanged: (value) => setState(() => _tipoMaterialForm = value!),
        validator: (v) => FormValidators.required(v, 'tipo de material'),
        decoration: inputDec('Tipo de material'),
      ),
      Row(
        spacing: 8,
        children: [
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: _controllers.get('idSitio'),
              decoration: inputDec('Id sitio'),
              validator: (v) => FormValidators.required(v, 'id'),
              inputFormatters: [LengthLimitingTextInputFormatter(20), FilteringTextInputFormatter.allow(lngExp)],
            ),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _controllers.get('nombreSitio'),
              decoration: inputDec('Nombre sitio'),
              validator: (v) => FormValidators.required(v, 'nombre'),
              inputFormatters: [LengthLimitingTextInputFormatter(50), FilteringTextInputFormatter.deny(notUsedExp)],
            ),
          ),
        ],
      ),
      TextFormField(
        controller: _controllers.get('cuentaCliente'),
        decoration: inputDec('Cuenta / Cliente'),
        validator: (v) => FormValidators.required(v, 'cuenta o cliente'),
        inputFormatters: [LengthLimitingTextInputFormatter(25), FilteringTextInputFormatter.deny(notUsedExp)],
      ),
      TextFormField(
        controller: _controllers.get('aspNombre'),
        decoration: inputDec('Nombre ASP'),
        validator: (v) => FormValidators.required(v, 'nombre asp'),
        inputFormatters: [LengthLimitingTextInputFormatter(50), FilteringTextInputFormatter.deny(notUsedExp)],
      ),
      SignatureCard(
        'Firma ASP',
        _firmaASP,
        existingSignature: _existingFASP,
        onRemake: () => setState(() => _existingFASP = null),
      ),
      TextFormField(
        controller: _controllers.get('nombreContacto'),
        decoration: inputDec('Nombre del contacto'),
        validator: (v) => FormValidators.required(v, 'contacto'),
        inputFormatters: [LengthLimitingTextInputFormatter(50), FilteringTextInputFormatter.deny(notUsedExp)],
      ),
      Row(
        spacing: 8,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _destinoForm,
              items: [
                for (var t in _catalogs?.warehouses ?? const <OptionSL>[])
                  DropdownMenuItem(
                    value: t.value,
                    child: Text(t.text, overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
              ],
              onChanged: (value) => setState(() => _destinoForm = value!),
              validator: (v) => FormValidators.required(v, 'almacén'),
              decoration: inputDec('Almacén destino'),
            ),
          ),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _idCarrierForm,
              decoration: inputDec('Carrier'),
              items: (_catalogs?.carriers ?? const <OptionSL>[])
                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.text)))
                  .toList(),
              onChanged: (v) => setState(() => _idCarrierForm = v),
              validator: (v) => FormValidators.required(v, 'carrier'),
            ),
          ),
        ],
      ),
      if (_idCarrierForm == '4')
        TextFormField(
          controller: _controllers.get('carrier'),
          decoration: inputDec('Nombre carrier'),
          validator: (v) => FormValidators.required(v, 'carrier'),
          inputFormatters: [LengthLimitingTextInputFormatter(50), FilteringTextInputFormatter.deny(notUsedExp)],
        ),
    ];
    final List<Widget> fieldsParts = [
      ExpansionListTile(
        'Piezas por motivo',
        'Agrega piezas por clave de motivo',
        _addEditPiezasMotivo,
        children: [
          for (var i = 0; i < _piezasMotivo.length; i++)
            _piezaItem(
              _piezasMotivo[i]['cl']!,
              _piezasMotivo[i]['pzs']!,
              onEdit: () => _addEditPiezasMotivo(i),
              onRemove: () => _removePiezas(i, _piezasMotivo, _piezasMotivoDel),
            ),
        ],
      ),
      ExpansionListTile(
        'Piezas por estado físico',
        'Agrega piezas por clave de estado físico',
        _addEditPiezasEstadoF,
        children: [
          for (var i = 0; i < _piezasEstadoF.length; i++)
            _piezaItem(
              _piezasEstadoF[i]['cl']!,
              _piezasEstadoF[i]['pzs']!,
              onEdit: () => _addEditPiezasEstadoF(i),
              onRemove: () => _removePiezas(i, _piezasEstadoF, _piezasEstadoFDel),
            ),
        ],
      ),
      TextFormField(
        controller: _controllers.get('totalPiezas'),
        decoration: inputDec('Total de piezas ${_es ? 'recibidas' : 'entregadas'}'),
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        inputFormatters: [LengthLimitingTextInputFormatter(10), FilteringTextInputFormatter.allow(numberExp)],
        validator: (value) {
          if (_piezasMotivo.isNotEmpty || _piezasEstadoF.isNotEmpty) {
            if (value == null || value.isEmpty) {
              return 'ingresa el total';
            } else if (int.parse(value) > 2000000000) {
              return 'Debe ser inferior a 2,000,000,000';
            }
          }
          return null;
        },
      ),
      ExpansionListTile(
        'Documentos',
        'Adjunta imágenes o PDF. Máximo 5 MB por archivo',
        _addEditDocumento,
        children: [
          for (var i = 0; i < _documentos.length; i++)
            _documentoItem(
              _documentos[i]['name'] ?? '',
              _documentos[i]['localPath'] ?? _documentos[i]['file'] ?? '',
              onEdit: () => _addEditDocumento(i),
              onRemove: () => _removeDocumento(i),
            ),
        ],
      ),
      Row(
        spacing: 8,
        children: [
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<bool>(
              initialValue: _tarimasForm,
              items: const [
                DropdownMenuItem(value: true, child: Text("Si")),
                DropdownMenuItem(value: false, child: Text("No")),
              ],
              onChanged: (value) => setState(() => _tarimasForm = value!),
              decoration: inputDec('Son tarimas'),
            ),
          ),
          if (_tarimasForm)
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _controllers.get('numTarimas'),
                decoration: inputDec('Número de tarimas'),
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [LengthLimitingTextInputFormatter(2), FilteringTextInputFormatter.allow(numberExp)],
                onChanged: (value) {
                  final num = int.tryParse(value) ?? 0;
                  if (num == 0 || num > 50 || _pfTarimas.length == (num * 2)) return;
                  if (mounted) {
                    setState(() {
                      if (_pfTarimas.length > (num * 2)) {
                        _pfTarimas.removeRange((num * 2), _pfTarimas.length);
                      } else {
                        for (var i = ((_pfTarimas.length / 2).truncate() + 1); i < (num + 1); i++) {
                          _pfTarimas.add(PhotoField('tarima_$i', 'Tarima $i'));
                          _pfTarimas.add(PhotoField('papeleta_$i', 'Papeleta $i'));
                        }
                      }
                    });
                  }
                },
                validator: (value) {
                  if (!_tarimasForm) return null;
                  final numValid = FormValidators.onlyNumbers(value, 'el número de tarimas');
                  if (numValid != null) {
                    return numValid;
                  } else if (int.parse(value!) > 50) {
                    return 'Máximo 50 pallets';
                  } else if (value == '0') {
                    return 'Debe ser al menos 1';
                  }
                  return null;
                },
              ),
            ),
        ],
      ),
      if (_tarimasForm)
        ExpansionTile(
          maintainState: true,
          shape: const Border(),
          tilePadding: EdgeInsets.symmetric(horizontal: 0),
          title: SectionTitle('Fotografías de las tarimas'),
          children: [PhotosGrid(context, _pfTarimas)],
        ),
      TextFormField(
        controller: _controllers.get('notas'),
        decoration: inputDec('Observaciones y notas'),
        minLines: 3,
        maxLines: 5,
        inputFormatters: [LengthLimitingTextInputFormatter(300), FilteringTextInputFormatter.deny(notUsedExp)],
      ),
    ];
    // Declarado antes para que en edición permita mostrar el valor.
    final TextFormField placasField = TextFormField(
      controller: _controllers.get('placasTransporte'),
      decoration: inputDec('Placas del transporte'),
      validator: (v) => FormValidators.required(v, 'placas'),
      inputFormatters: [
        UpperCaseTextFormatter(),
        LengthLimitingTextInputFormatter(20),
        FilteringTextInputFormatter.allow(lngExp),
      ],
    );

    return Scaffold(
      appBar: AppBarHeader(
        '${_isEdition ? 'Edición M.' : 'Material de'} ${_es ? 'Entrada' : 'Salida'}',
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              if (!_isEdition) PopupMenuItem(onTap: _loadDraft, child: Text('Cargar borrador')),
              if (!_isEdition) PopupMenuItem(onTap: _saveDraft, child: Text('Guardar borrador')),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: _isBuilding
                ? Center(child: CircularProgressIndicator())
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        spacing: 16,
                        children: [
                          InfoLetterChip(materialValidationLetter),
                          MasonryGridView.count(
                            crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: fields.length,
                            itemBuilder: (context, index) => fields[index],
                          ),
                          SectionTitle('Datos generales'),
                          MasonryGridView.count(
                            crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: generalFields.length,
                            itemBuilder: (context, index) => generalFields[index],
                          ),
                          SectionTitle('Transporte y material'),
                          placasField,
                          PhotosGrid(context, _photoFields, watermark: _watermark),
                          SectionTitle(
                            'Registro de evidencias',
                            subtitle: 'Registre al menos una pieza, documento o tarima',
                          ),
                          MasonryGridView.count(
                            crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: fieldsParts.length,
                            itemBuilder: (context, index) => fieldsParts[index],
                          ),
                          _isSubmitting
                              ? const Center(child: CircularProgressIndicator())
                              : Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        icon: Icon(_isEdition ? Icons.save : Icons.check),
                                        onPressed: _submit,
                                        label: Text(
                                          _isEdition ? 'GUARDAR CAMBIOS' : 'VALIDAR ${_es ? 'ENTRADA' : 'SALIDA'}',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
