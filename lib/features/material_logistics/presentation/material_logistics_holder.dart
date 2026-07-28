import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/services/s3_service.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/material_logistics_service.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/sitio_draft.dart';

/// Vistas tope del shell. El orden coincide con los hijos del `IndexedStack`
/// (`.index`): 0 = Cabecera, 1 = Sitios.
enum LogisticsView { cabecera, sitios }

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int? _toInt(String? v) => (v == null || v.isEmpty) ? null : int.tryParse(v);

const String _evidenceFolder = 'material_logistics/';

/// State holder del formulario de Logística de Material, con alcance de ruta.
/// Ambas pantallas (Cabecera / Sitios) lo observan vía `provider`.
///
/// Sin objetos de widget a propósito (los `TextEditingController`/`FormKey` viven
/// en el `State` de cada pantalla). Texto libre → [commitHeader]; el resto
/// (dropdowns, toggles, pickers) usa setters que notifican en el momento.
class MaterialLogisticsHolder extends ChangeNotifier {
  // dentro de la clase: dependencias de I/O + dispose
  final MaterialLogisticsService _service = MaterialLogisticsService();
  final S3Service _s3 = S3Service();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  /// En edición se entra directo a Sitios (resumen de cabecera + lista de sitios),
  /// no a un wizard lineal; en creación se arranca por la Cabecera.
  MaterialLogisticsHolder({MaterialLogistics? record})
      : _original = record,
        _view = record != null ? LogisticsView.sitios : LogisticsView.cabecera {
    _seedHeader(record);
    _seedSitios(record);
  }

  /// Snapshot tal como se cargó (null en creación). Base del diff de edición.
  final MaterialLogistics? _original;
  MaterialLogistics? get original => _original;

  bool get isEdition => _original != null;

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

  void setIdCarrier(String? value) {
    if (_idCarrier == value) return;
    _idCarrier = value;
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

  /// Alta (index null) o reemplazo (index dado) de un sitio. La pantalla pasa una
  /// `copy()` ya editada; el reemplazo conserva el baseline para el diff.
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

  // Payloads
  /// `idUsuario` se inyecta desde la sesión en el submit (Fase 7).

  /// Cabecera + `sitios:[...]`. `re`/`confirmado` van en creación.
  Map<String, dynamic> buildCreatePayload({required int idUsuario}) {
    final carrierId = _toInt(_idCarrier);
    return {
      'idUsuario': idUsuario,
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
      'idCarrier': carrierId,
      'otroCarrier': carrierId == 4 ? (_otroCarrier.isEmpty ? null : _otroCarrier) : null,
      'sitios': _sitios.map((s) => s.toCreateJson()).toList(),
    };
  }

  /// Diff de cabecera (COALESCE: campo ausente = sin cambio) + sitios por diff.
  /// `RE`/`confirmado` no se envían. `nombreResponsable`: `""` = limpiar (usar usuario).
  /// `otroCarrier` solo se envía con carrier 4; si deja de ser 4, el SP lo limpia solo.
  Map<String, dynamic> buildUpdatePayload({required int idUsuario}) {
    final o = _original!; // edición garantiza snapshot
    final payload = <String, dynamic>{
      'idLogistica': o.id,
      'idUsuario': idUsuario,
    };

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
    // otroCarrier: solo con carrier 4 y si cambió; el SP autolimpia al dejar de ser 4.
    if (carrierId == 4) {
      final otro = _otroCarrier.isEmpty ? null : _otroCarrier;
      if (otro != o.otroCarrier) payload['otroCarrier'] = otro;
    }

    if (_sitiosDel.isNotEmpty) payload['sitiosDel'] = List<int>.from(_sitiosDel);
    final add = _sitios.where((s) => s.isNew).map((s) => s.toCreateJson()).toList();
    if (add.isNotEmpty) payload['sitiosAdd'] = add;
    final edit = _sitios.where((s) => !s.isNew && s.hasChanges).map((s) => s.toEditJson()).toList();
    if (edit.isNotEmpty) payload['sitiosEdit'] = edit;

    return payload;
  }

  /// Borrador (solo creación; el caller guarda con `!isEdition`). Excluye evidencias.
  Map<String, dynamic> buildDraft() => {
        'fecha': _fecha?.toIso8601String(),
        'idXdock': _idXdock,
        're': _re,
        'idCarrier': _idCarrier,
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
          (json['sitios'] as List? ?? const []).map((s) => SitioDraft.fromDraft(Map<String, dynamic>.from(s as Map))));
    notifyListeners();
  }

  /// Mime inferido del path local (las tarimas no guardan mimeType; siempre son imagen).
  String _mimeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  /// Sube un archivo local a S3, borra la key anterior si la había y devuelve la nueva key relativa.
  /// Lanza Exception si la subida falla.
  Future<String> _uploadFile({
    required String localPath,
    required String contentType,
    required String oldKey,
    required int idUsuario,
    required int stamp,
    required int seq,
  }) async {
    final bytes = await File(localPath).readAsBytes();
    final ext = contentType.contains('pdf') ? 'pdf' : (contentType.contains('png') ? 'png' : 'jpg');
    final key = '$_evidenceFolder$idUsuario/$stamp-$seq.$ext';
    final url = await _s3.uploadU8LToS3(bytes, key, contentType);
    if (url == null) throw Exception('Falló la subida a S3 ($key)');
    if (oldKey.isNotEmpty) await _s3.deleteFromS3(oldKey);
    return key;
  }

  /// Sube las evidencias y tarimas (par de fotos) `localPath`,
  /// fija sus keys relativas y borra las anteriores si las había.
  Future<bool> _uploadPendingFiles(int idUsuario) async {
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
                idUsuario: idUsuario,
                stamp: stamp,
                seq: seq++);
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
                idUsuario: idUsuario,
                stamp: stamp,
                seq: seq++);
            t.tarimaLocalPath = null;
          }
          final plp = t.papeletaLocalPath;
          if (plp != null && plp.isNotEmpty) {
            t.papeletaFoto = await _uploadFile(
                localPath: plp,
                contentType: _mimeFromPath(plp),
                oldKey: t.papeletaFoto,
                idUsuario: idUsuario,
                stamp: stamp,
                seq: seq++);
            t.papeletaLocalPath = null;
          }
        }
      }
      return true;
    } catch (err) {
      DebugLog.error('Error subiendo archivos: $err');
      return false;
    }
  }

  /// Sube evidencias pendientes y envía (create o update). `idUsuario` de sesión.
  /// La pantalla muestra `response.message`.
  Future<ServiceResponse<String>> submit({required int idUsuario}) async {
    if (!await _uploadPendingFiles(idUsuario)) {
      return ServiceResponse(false, message: 'Error al subir uno o más archivos.', data: '');
    }
    if (isEdition) {
      final payload = buildUpdatePayload(idUsuario: idUsuario);
      if (payload.length <= 2) {
        return ServiceResponse(false, message: 'No se hicieron cambios.', data: '');
      }
      return _service.recepcionEntrega(payload, _re, true);
    }
    return _service.recepcionEntrega(buildCreatePayload(idUsuario: idUsuario), _re, false);
  }
}
