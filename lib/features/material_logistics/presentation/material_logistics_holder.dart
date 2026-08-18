import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/services/s3_service.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/material_logistics_service.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/sitio_draft.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/document_draft.dart';

/// Vistas tope del shell. El orden coincide con los hijos del `IndexedStack`
/// (`.index`): 0 = Cabecera, 1 = Sitios.
enum LogisticsView { cabecera, sitios }

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int? _toInt(String? v) => (v == null || v.isEmpty) ? null : int.tryParse(v);

const String _feature = 'material_logistics';

/// State holder del formulario de Logística de Material, con alcance de ruta.
/// Ambas pantallas (Cabecera / Sitios) lo observan vía `provider`.
///
/// Identidad del actor (`idUsuario`/`TenantID`) sale del token: **no** viaja en
/// crear/editar. En edición el registro se identifica por `folio` en la URL del
/// `PUT` (no `idLogistica` en el body).
class MaterialLogisticsHolder extends ChangeNotifier {
  final MaterialLogisticsService _service = MaterialLogisticsService();
  final S3Service _s3 = S3Service();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  /// En edición se entra directo a Sitios; en creación se arranca por la Cabecera.
  MaterialLogisticsHolder({MaterialLogistics? record})
    : _original = record,
      _view = record != null ? LogisticsView.sitios : LogisticsView.cabecera {
    _seedHeader(record);
    _seedSitios(record);
    _seedDocumentos(record);
  }

  /// Snapshot tal como se cargó (null en creación). Base del diff de edición.
  final MaterialLogistics? _original;
  MaterialLogistics? get original => _original;

  bool get isEdition => _original != null;

  /// Folio del registro en edición (para `PUT /{folio}`). '' en creación.
  String get folio => _original?.folio ?? '';

  // Vista
  LogisticsView _view;
  LogisticsView get view => _view;

  void goToSitios() {
    if (_view == LogisticsView.sitios) return;
    _view = LogisticsView.sitios;
    notifyListeners();
  }

  void backToCabecera() {
    if (_view == LogisticsView.cabecera) return;
    _view = LogisticsView.cabecera;
    notifyListeners();
  }

  // Cabecera
  DateTime? _fecha;
  String? _idXdock; // value de OptionSL
  bool _re = true; // true = Recepción, false = Entrega (inmutable en edición)
  String? _idCarrier; // value de OptionSL
  bool _carrierEsOtro = false; // resuelto del catálogo (no por id fijo)
  String _otroCarrier = '';
  String? _horaLlegada; // "HH:mm:ss"
  String? _horaInicioDescarga; // "HH:mm:ss"
  String? _horaSalida; // "HH:mm:ss"
  String? _nombreResponsable; // null = el responsable es el usuario
  String _unidadPlaca = '';
  String _nombreOperador = '';
  bool _confirmado = false;

  void _seedHeader(MaterialLogistics? r) {
    if (r == null) {
      _fecha = DateTime.now();
      return;
    }
    _fecha = DateTime.tryParse(r.fecha) ?? DateTime.now();
    _idXdock = r.idXdock != 0 ? r.idXdock.toString() : null;
    _re = r.re;
    _idCarrier = r.idCarrier != 0 ? r.idCarrier.toString() : null;
    _carrierEsOtro = r.esOtro; // del registro; si el usuario lo cambia, el form lo re-resuelve
    _otroCarrier = r.otroCarrier ?? '';
    _horaLlegada = r.horaLlegada.isEmpty ? null : r.horaLlegada;
    _horaInicioDescarga = r.horaInicioDescarga.isEmpty ? null : r.horaInicioDescarga;
    _horaSalida = r.horaSalida.isEmpty ? null : r.horaSalida;
    _nombreResponsable = r.nombreResponsable;
    _unidadPlaca = r.unidadPlaca;
    _nombreOperador = r.nombreOperador;
    _confirmado = r.confirmado;
  }

  // Getters
  DateTime? get fecha => _fecha;
  String? get idXdock => _idXdock;
  bool get re => _re;
  String? get idCarrier => _idCarrier;
  bool get carrierEsOtro => _carrierEsOtro;
  String get otroCarrier => _otroCarrier;
  String? get horaLlegada => _horaLlegada;
  String? get horaInicioDescarga => _horaInicioDescarga;
  String? get horaSalida => _horaSalida;
  String? get nombreResponsable => _nombreResponsable;
  String get unidadPlaca => _unidadPlaca;
  String get nombreOperador => _nombreOperador;
  bool get confirmado => _confirmado;

  // Setters "live" (dropdowns / toggles / pickers)
  void setFecha(DateTime value) {
    _fecha = value;
    notifyListeners();
  }

  void setIdXdock(String? value) {
    if (_idXdock == value) return;
    _idXdock = value;
    notifyListeners();
  }

  /// Inmutable en edición: el cambio se ignora (la UI además deshabilita el control).
  void setRe(bool value) {
    if (isEdition || _re == value) return;
    _re = value;
    notifyListeners();
  }

  /// El `esOtro` lo resuelve el caller desde el catálogo (`LogisticsCatalogs.isCarrierOtro`),
  /// nunca por `id == 4`. Si el carrier deja de ser "Otro", el nombre libre se limpia.
  void setIdCarrier(String? value, {required bool esOtro}) {
    if (_idCarrier == value && _carrierEsOtro == esOtro) return;
    _idCarrier = value;
    _carrierEsOtro = esOtro;
    if (!esOtro) _otroCarrier = '';
    notifyListeners();
  }

  void setHoraLlegada(String? value) {
    if (_horaLlegada == value) return;
    _horaLlegada = value;
    notifyListeners();
  }

  void setHoraInicioDescarga(String? value) {
    if (_horaInicioDescarga == value) return;
    _horaInicioDescarga = value;
    notifyListeners();
  }

  void setHoraSalida(String? value) {
    if (_horaSalida == value) return;
    _horaSalida = value;
    notifyListeners();
  }

  void setConfirmado(bool value) {
    if (_confirmado == value) return;
    _confirmado = value;
    notifyListeners();
  }

  /// Vuelca el texto libre de la Cabecera al holder en el "Continuar".
  /// `nombreResponsable` null = usar al usuario. `otroCarrier` solo aplica con
  /// carrier "Otro"; los builders anulan lo que no corresponda.
  void commitHeader({
    String? nombreResponsable,
    required String unidadPlaca,
    required String nombreOperador,
    String otroCarrier = '',
  }) {
    _nombreResponsable = nombreResponsable;
    _unidadPlaca = unidadPlaca;
    _nombreOperador = nombreOperador;
    _otroCarrier = otroCarrier;
    notifyListeners();
  }

  // Sitios
  final List<SitioDraft> _sitios = [];
  final List<int> _sitiosDel = []; // IdLogisticaSitio de sitios persistidos eliminados

  void _seedSitios(MaterialLogistics? r) {
    if (r == null) return;
    _sitios.addAll(r.sitios.map(SitioDraft.fromSite));
  }

  List<SitioDraft> get sitios => List.unmodifiable(_sitios);
  List<int> get sitiosDel => List.unmodifiable(_sitiosDel);

  SitioDraft? getSitio(int index) => (index >= 0 && index < _sitios.length) ? _sitios[index] : null;

  /// Alta (index null) o reemplazo (index dado) de un sitio.
  void upsertSitio(SitioDraft draft, {int? index}) {
    if (index != null && index >= 0 && index < _sitios.length) {
      _sitios[index] = draft;
    } else {
      _sitios.add(draft);
    }
    notifyListeners();
  }

  /// Elimina un sitio; si estaba persistido, registra su `id` en `sitiosDel`.
  void removeSitio(int index) {
    if (index < 0 || index >= _sitios.length) return;
    final removed = _sitios.removeAt(index);
    if (removed.id != null) _sitiosDel.add(removed.id!);
    notifyListeners();
  }

  // Documentos de cabecera (bucket a nivel arribo — nuevo en la app)
  final List<DocumentDraft> _documentos = [];

  void _seedDocumentos(MaterialLogistics? r) {
    if (r == null) return;
    _documentos.addAll(r.documentos.whereType<Map>().map((d) => DocumentDraft.fromRead(d.cast<String, dynamic>())));
  }

  List<DocumentDraft> get documentos => List.unmodifiable(_documentos);

  void addDocumento(DocumentDraft doc) {
    _documentos.add(doc);
    notifyListeners();
  }

  void updateDocumento(int index, DocumentDraft doc) {
    if (index < 0 || index >= _documentos.length) return;
    _documentos[index] = doc;
    notifyListeners();
  }

  void removeDocumento(int index) {
    if (index < 0 || index >= _documentos.length) return;
    _documentos.removeAt(index);
    notifyListeners();
  }

  /// True si el set de documentos difiere del original (contenido) o hay alguno
  /// pendiente de subir. Base del reemplazo total en update: si cambió, se manda
  /// la lista completa vigente; si no, se omite.
  bool get _documentosChanged {
    final base =
        _original?.documentos.whereType<Map>().map((d) => DocumentDraft.fromRead(d.cast<String, dynamic>())).toList() ??
        const <DocumentDraft>[];
    if (_documentos.any((d) => d.localPath != null && d.localPath!.isNotEmpty)) return true;
    if (_documentos.length != base.length) return true;
    for (var i = 0; i < _documentos.length; i++) {
      if (!_documentos[i].sameAs(base[i])) return true;
    }
    return false;
  }

  // Payloads

  /// Cabecera + `sitios:[...]` + `documentos:[...]` (opcional). **Sin** `idUsuario`.
  /// `re`/`confirmado` van en creación.
  Map<String, dynamic> buildCreatePayload() {
    final payload = <String, dynamic>{
      'fecha': _fecha != null ? _fmtDate(_fecha!) : null,
      'idXdock': _toInt(_idXdock),
      'nombreResponsable': _nombreResponsable, // null = usuario
      'unidadPlaca': _unidadPlaca,
      'nombreOperador': _nombreOperador,
      'horaLlegada': _horaLlegada,
      'horaInicioDescarga': _horaInicioDescarga,
      'horaSalida': _horaSalida,
      'confirmado': _confirmado,
      're': _re,
      'idCarrier': _toInt(_idCarrier),
      'otroCarrier': _carrierEsOtro ? (_otroCarrier.isEmpty ? null : _otroCarrier) : null,
      'sitios': _sitios.map((s) => s.toCreateJson()).toList(),
    };
    if (_documentos.isNotEmpty) {
      payload['documentos'] = _documentos.map((d) => d.toJson()).toList();
    }
    return payload;
  }

  /// Diff de cabecera (COALESCE: campo ausente = sin cambio) + sitios por diff + documentos por reemplazo total.
  /// `re`/`confirmado` no se envían. `nombreResponsable`: `""` = limpiar (usar usuario).
  Map<String, dynamic> buildUpdatePayload() {
    final o = _original!; // edición garantiza snapshot
    final payload = <String, dynamic>{};

    final fechaStr = _fecha != null ? _fmtDate(_fecha!) : null;
    if (fechaStr != null && fechaStr != o.fecha) payload['fecha'] = fechaStr;

    final xdock = _toInt(_idXdock);
    if (xdock != null && xdock != o.idXdock) payload['idXdock'] = xdock;

    if (_nombreResponsable != o.nombreResponsable) {
      payload['nombreResponsable'] = _nombreResponsable ?? ''; // null tras override → "" (limpiar)
    }

    if (_unidadPlaca != o.unidadPlaca) payload['unidadPlaca'] = _unidadPlaca;
    if (_nombreOperador != o.nombreOperador) payload['nombreOperador'] = _nombreOperador;
    if ((_horaLlegada ?? '') != o.horaLlegada) payload['horaLlegada'] = _horaLlegada;
    if ((_horaInicioDescarga ?? '') != o.horaInicioDescarga) payload['horaInicioDescarga'] = _horaInicioDescarga;
    if ((_horaSalida ?? '') != o.horaSalida) payload['horaSalida'] = _horaSalida;

    final carrierId = _toInt(_idCarrier);
    if (carrierId != null && carrierId != o.idCarrier) payload['idCarrier'] = carrierId;
    // otroCarrier: solo con carrier "Otro" (por catálogo) y si cambió; el SP auto-limpia al dejar de serlo.
    if (_carrierEsOtro) {
      final otro = _otroCarrier.isEmpty ? null : _otroCarrier;
      if (otro != o.otroCarrier) payload['otroCarrier'] = otro;
    }

    if (_sitiosDel.isNotEmpty) payload['sitiosDel'] = List<int>.from(_sitiosDel);
    final add = _sitios.where((s) => s.isNew).map((s) => s.toCreateJson()).toList();
    if (add.isNotEmpty) payload['sitiosAdd'] = add;
    final edit = _sitios.where((s) => !s.isNew && s.hasChanges).map((s) => s.toEditJson()).toList();
    if (edit.isNotEmpty) payload['sitiosEdit'] = edit;

    // Documentos: reemplazo total. Si cambió, manda la lista completa vigente
    // ([] borra todos); si no cambió, se omite (sin cambio).
    if (_documentosChanged) {
      payload['documentos'] = _documentos.map((d) => d.toJson()).toList();
    }

    return payload;
  }

  /// Borrador (solo creación). Excluye archivos (evidencias, tarimas, documentos).
  Map<String, dynamic> buildDraft() => {
    'fecha': _fecha?.toIso8601String(),
    'idXdock': _idXdock,
    're': _re,
    'idCarrier': _idCarrier,
    'carrierEsOtro': _carrierEsOtro,
    'otroCarrier': _otroCarrier,
    'horaLlegada': _horaLlegada,
    'horaInicioDescarga': _horaInicioDescarga,
    'horaSalida': _horaSalida,
    'nombreResponsable': _nombreResponsable,
    'unidadPlaca': _unidadPlaca,
    'nombreOperador': _nombreOperador,
    // 'confirmado' excluido a propósito: el usuario re-confirma al restaurar.
    'sitios': _sitios.map((s) => s.toDraftJson()).toList(),
  };

  void loadDraft(Map<String, dynamic> json) {
    _fecha = DateTime.tryParse(json['fecha'] ?? '') ?? _fecha;
    _idXdock = json['idXdock'];
    _re = json['re'] ?? _re;
    _idCarrier = json['idCarrier'];
    _carrierEsOtro = json['carrierEsOtro'] ?? false;
    _otroCarrier = json['otroCarrier'] ?? '';
    _horaLlegada = json['horaLlegada'];
    _horaInicioDescarga = json['horaInicioDescarga'];
    _horaSalida = json['horaSalida'];
    _nombreResponsable = json['nombreResponsable'];
    _unidadPlaca = json['unidadPlaca'] ?? '';
    _nombreOperador = json['nombreOperador'] ?? '';
    // confirmado se deja en su valor actual (false) a propósito.
    _sitios
      ..clear()
      ..addAll(
        (json['sitios'] as List? ?? const []).map((s) => SitioDraft.fromDraft(Map<String, dynamic>.from(s as Map))),
      );
    notifyListeners();
  }

  /// Mime inferido del path local (las tarimas no guardan mimeType; siempre imagen).
  String _mimeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  /// Carpeta relativa base por tenant + usuario: `{slug}/material_logistics/{idUsuario}/`.
  /// El prefijo de entorno (`Qa/`|`Pr/`) lo antepone `S3Service` de forma global.
  /// Alinea la llave con `material_validation` (`{slug}/material_validation/{userId}/…`).
  String _baseFolder(int idUsuario) {
    final slug = TenantContext.instance.slug;
    final tenant = (slug != null && slug.isNotEmpty) ? '$slug/' : '';
    return '$tenant$_feature/$idUsuario/';
  }

  /// Sube un archivo local a S3, borra la key anterior si la había y devuelve la
  /// nueva key relativa. Lanza Exception si la subida falla.
  Future<String> _uploadFile({
    required String localPath,
    required String contentType,
    required String oldKey,
    required String folder,
    required int stamp,
    required int seq,
  }) async {
    final bytes = await File(localPath).readAsBytes();
    final ext = contentType.contains('pdf') ? 'pdf' : (contentType.contains('png') ? 'png' : 'jpg');
    final relKey = '$folder$stamp-$seq.$ext';
    final fullKey = '${Config.s3Folder}/$relKey';
    final url = await _s3.uploadU8LToS3(bytes, fullKey, contentType);
    if (url == null) throw Exception('Falló la subida a S3 ($fullKey)');
    if (oldKey.isNotEmpty) await _s3.deleteFromS3(oldKey);
    return fullKey;
  }

  /// Sube evidencias/tarimas por sitio y documentos de cabecera pendientes,
  /// fija sus keys relativas y borra las anteriores si las había.
  Future<bool> _uploadPendingFiles(int idUsuario) async {
    final base = _baseFolder(idUsuario);
    final docsFolder = '${base}docs/';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    int seq = 0;
    try {
      for (final sitio in _sitios) {
        for (final e in sitio.evidencias) {
          final lp = e.localPath;
          if (lp != null && lp.isNotEmpty) {
            e.archivo = await _uploadFile(
              localPath: lp,
              contentType: e.mimeType,
              oldKey: e.archivo,
              folder: base,
              stamp: stamp,
              seq: seq++,
            );
            e.localPath = null;
          }
        }
        for (final t in sitio.tarimas) {
          final tlp = t.tarimaLocalPath;
          if (tlp != null && tlp.isNotEmpty) {
            t.tarimaFoto = await _uploadFile(
              localPath: tlp,
              contentType: _mimeFromPath(tlp),
              oldKey: t.tarimaFoto,
              folder: base,
              stamp: stamp,
              seq: seq++,
            );
            t.tarimaLocalPath = null;
          }
          final plp = t.papeletaLocalPath;
          if (plp != null && plp.isNotEmpty) {
            t.papeletaFoto = await _uploadFile(
              localPath: plp,
              contentType: _mimeFromPath(plp),
              oldKey: t.papeletaFoto,
              folder: base,
              stamp: stamp,
              seq: seq++,
            );
            t.papeletaLocalPath = null;
          }
        }
      }
      // Documentos de cabecera.
      for (final d in _documentos) {
        final lp = d.localPath;
        if (lp != null && lp.isNotEmpty) {
          d.archivo = await _uploadFile(
            localPath: lp,
            contentType: d.mimeType.isNotEmpty ? d.mimeType : _mimeFromPath(lp),
            oldKey: d.archivo,
            folder: docsFolder,
            stamp: stamp,
            seq: seq++,
          );
          d.localPath = null;
        }
      }
      return true;
    } catch (err) {
      DebugLog.error('Error subiendo archivos: $err');
      return false;
    }
  }

  /// Sube archivos pendientes y envía (create o update).
  /// `idUsuario` de sesión (solo para la ruta de la llave S3; no viaja en el payload).
  /// La pantalla muestra `response.message`; `data` = folio (create) o el folio en edición.
  Future<ServiceResponse<String>> submit({required int idUsuario}) async {
    if (!await _uploadPendingFiles(idUsuario)) {
      return ServiceResponse.error('Error al subir uno o más archivos.');
    }
    final tipo = _re ? 'Recepción' : 'Entrega';
    if (isEdition) {
      final payload = buildUpdatePayload();
      if (payload.isEmpty) {
        return ServiceResponse.error('No se hicieron cambios.');
      }
      final res = await _service.updateRecord(folio, payload);
      if (!res.success) return ServiceResponse.error(res.message, statusCode: res.statusCode);
      return ServiceResponse(true, data: folio, message: '$tipo actualizada con éxito.', statusCode: res.statusCode);
    }
    final res = await _service.createRecord(buildCreatePayload());
    if (!res.success) return res;
    return ServiceResponse(true, data: res.data, message: '$tipo creada con éxito.', statusCode: res.statusCode);
  }
}
