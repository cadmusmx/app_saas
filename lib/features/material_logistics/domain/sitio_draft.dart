import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';

Set<int> _idTipos(List<dynamic> raw) => raw.map((e) => (e as Map)['idTipo'] as int).toSet();

/// Evidencia en el modelo de trabajo. `id` null = nueva (aún no persistida).
/// `archivo` es la key de S3; para evidencias nuevas `localPath` apunta al archivo
/// local que la orquestación de subida (holder) reemplaza por la key final.
class EvidenceDraft {
  final int? id;
  int idTipoEvidencia;
  String archivo;
  String mimeType;
  int orden;
  String? localPath; // ruta local pendiente de subir; null = ya tiene key en `archivo`

  EvidenceDraft({
    this.id,
    required this.idTipoEvidencia,
    required this.archivo,
    required this.mimeType,
    required this.orden,
    this.localPath,
  });

  factory EvidenceDraft.fromRead(Map<String, dynamic> j) => EvidenceDraft(
        id: j['id'],
        idTipoEvidencia: j['idTipo'] ?? 0,
        archivo: j['archivo'] ?? '',
        mimeType: j['mimeType'] ?? '',
        orden: j['orden'] ?? 0,
      );

  EvidenceDraft copy() => EvidenceDraft(
        id: id,
        idTipoEvidencia: idTipoEvidencia,
        archivo: archivo,
        mimeType: mimeType,
        orden: orden,
        localPath: localPath,
      );

  bool sameAs(EvidenceDraft o) =>
      idTipoEvidencia == o.idTipoEvidencia && archivo == o.archivo && mimeType == o.mimeType && orden == o.orden;

  Map<String, dynamic> toAddJson() => {
        'idTipoEvidencia': idTipoEvidencia,
        'archivo': archivo,
        'mimeType': mimeType,
        'orden': orden,
      };

  Map<String, dynamic> toEditJson() => {
        'id': id,
        'idTipoEvidencia': idTipoEvidencia,
        'archivo': archivo,
        'mimeType': mimeType,
        'orden': orden,
      };
}

/// Tarima en el modelo de trabajo: par de fotos (tarima + papeleta).
/// Ambas requeridas. `tarimaFoto`/`papeletaFoto` son keys de S3;
/// los `*LocalPath` apuntan al archivo local pendiente de subir (el holder fija la key al subir).
/// Las tarimas se envían como **conjunto completo** (no diff), por eso no usan id.
class TarimaDraft {
  final int? id;
  String tarimaFoto;
  String papeletaFoto;
  int orden;
  String? tarimaLocalPath;
  String? papeletaLocalPath;

  TarimaDraft({
    this.id,
    required this.tarimaFoto,
    required this.papeletaFoto,
    required this.orden,
    this.tarimaLocalPath,
    this.papeletaLocalPath,
  });

  factory TarimaDraft.fromRead(Map<String, dynamic> j) => TarimaDraft(
        id: j['id'],
        tarimaFoto: j['tarimaFoto'] ?? '',
        papeletaFoto: j['papeletaFoto'] ?? '',
        orden: j['orden'] ?? 0,
      );

  TarimaDraft copy() => TarimaDraft(
        id: id,
        tarimaFoto: tarimaFoto,
        papeletaFoto: papeletaFoto,
        orden: orden,
        tarimaLocalPath: tarimaLocalPath,
        papeletaLocalPath: papeletaLocalPath,
      );

  bool sameAs(TarimaDraft o) => tarimaFoto == o.tarimaFoto && papeletaFoto == o.papeletaFoto && orden == o.orden;

  /// Conjunto completo (create y edit): sin id (el backend reemplaza todo).
  Map<String, dynamic> toJson() => {
        'tarimaFoto': tarimaFoto,
        'papeletaFoto': papeletaFoto,
        'orden': orden,
      };
}

/// Modelo de trabajo mutable de un sitio.
/// La pantalla edita una `copy()` y la confirma con `upsertSitio`; si se cancela, el original queda intacto.
/// Conserva su baseline (de la lectura) para producir el diff de edición.
class SitioDraft {
  final int? id; // IdLogisticaSitio (fila); null = sitio nuevo
  String idSitio;
  String nombreSitio;
  String descripcionMaterial;
  bool materialFaltante;
  String? descripcionFaltantes;
  String? descripcionIncidencias;
  final Set<int> tipos; // idTipoMaterial
  final Set<int> incidencias; // idTipoIncidencia
  final List<EvidenceDraft> evidencias;
  final List<TarimaDraft> tarimas;

  // Baseline inmutable (vacío/igual en sitios nuevos) para el diff y hasChanges.
  final String _baselineIdSitio;
  final String _baselineNombreSitio;
  final String _baselineDescripcionMaterial;
  final bool _baselineMaterialFaltante;
  final String? _baselineDescripcionFaltantes;
  final String? _baselineDescripcionIncidencias;
  final Set<int> _baselineTipos;
  final Set<int> _baselineIncidencias;
  final List<EvidenceDraft> _baselineEvidencias;
  final List<TarimaDraft> _baselineTarimas;

  SitioDraft._({
    required this.id,
    required this.idSitio,
    required this.nombreSitio,
    required this.descripcionMaterial,
    required this.materialFaltante,
    required this.descripcionFaltantes,
    required this.descripcionIncidencias,
    required this.tipos,
    required this.incidencias,
    required this.evidencias,
    required this.tarimas,
    required String baselineIdSitio,
    required String baselineNombreSitio,
    required String baselineDescripcionMaterial,
    required bool baselineMaterialFaltante,
    required String? baselineDescripcionFaltantes,
    required String? baselineDescripcionIncidencias,
    required Set<int> baselineTipos,
    required Set<int> baselineIncidencias,
    required List<EvidenceDraft> baselineEvidencias,
    required List<TarimaDraft> baselineTarimas,
  })  : _baselineIdSitio = baselineIdSitio,
        _baselineNombreSitio = baselineNombreSitio,
        _baselineDescripcionMaterial = baselineDescripcionMaterial,
        _baselineMaterialFaltante = baselineMaterialFaltante,
        _baselineDescripcionFaltantes = baselineDescripcionFaltantes,
        _baselineDescripcionIncidencias = baselineDescripcionIncidencias,
        _baselineTipos = baselineTipos,
        _baselineIncidencias = baselineIncidencias,
        _baselineEvidencias = baselineEvidencias,
        _baselineTarimas = baselineTarimas;

  /// Sitio nuevo (sin baseline real; va a `sitiosAdd`, no a `sitiosEdit`).
  factory SitioDraft.nuevo() => SitioDraft._(
        id: null,
        idSitio: '',
        nombreSitio: '',
        descripcionMaterial: '',
        materialFaltante: false,
        descripcionFaltantes: null,
        descripcionIncidencias: null,
        tipos: {},
        incidencias: {},
        evidencias: [],
        tarimas: [],
        baselineIdSitio: '',
        baselineNombreSitio: '',
        baselineDescripcionMaterial: '',
        baselineMaterialFaltante: false,
        baselineDescripcionFaltantes: null,
        baselineDescripcionIncidencias: null,
        baselineTipos: const {},
        baselineIncidencias: const {},
        baselineEvidencias: const [],
        baselineTarimas: const [],
      );

  /// Desde la lectura: siembra working + baseline (copias independientes).
  factory SitioDraft.fromSite(LogisticsSite s) {
    final tipos = _idTipos(s.tiposMaterial);
    final incid = _idTipos(s.incidencias);
    final evs = s.evidencias.map((e) => EvidenceDraft.fromRead(Map<String, dynamic>.from(e as Map))).toList();
    final tars = s.tarimas.map((t) => TarimaDraft.fromRead(Map<String, dynamic>.from(t as Map))).toList();
    return SitioDraft._(
      id: s.id,
      idSitio: s.idSitio,
      nombreSitio: s.nombreSitio,
      descripcionMaterial: s.descripcionMaterial,
      materialFaltante: s.materialFaltante,
      descripcionFaltantes: s.descripcionFaltantes,
      descripcionIncidencias: s.descripcionIncidencias,
      tipos: {...tipos},
      incidencias: {...incid},
      evidencias: evs,
      tarimas: tars,
      baselineIdSitio: s.idSitio,
      baselineNombreSitio: s.nombreSitio,
      baselineDescripcionMaterial: s.descripcionMaterial,
      baselineMaterialFaltante: s.materialFaltante,
      baselineDescripcionFaltantes: s.descripcionFaltantes,
      baselineDescripcionIncidencias: s.descripcionIncidencias,
      baselineTipos: {...tipos},
      baselineIncidencias: {...incid},
      baselineEvidencias: evs.map((e) => e.copy()).toList(),
      baselineTarimas: tars.map((t) => t.copy()).toList(),
    );
  }

  /// Reconstruye un sitio nuevo desde un borrador (sin id, sin baseline, sin archivos).
  factory SitioDraft.fromDraft(Map<String, dynamic> j) {
    final s = SitioDraft.nuevo();
    s.idSitio = j['idSitio'] ?? '';
    s.nombreSitio = j['nombreSitio'] ?? '';
    s.descripcionMaterial = j['descripcionMaterial'] ?? '';
    s.materialFaltante = j['materialFaltante'] ?? false;
    s.descripcionFaltantes = j['descripcionFaltantes'];
    s.descripcionIncidencias = j['descripcionIncidencias'];
    s.tipos.addAll((j['tipos'] as List? ?? const []).map((e) => e as int));
    s.incidencias.addAll((j['incidencias'] as List? ?? const []).map((e) => e as int));
    return s;
  }

  /// Serialización para borrador: encabezado + selecciones, SIN archivos
  /// (evidencias y tarimas se excluyen del borrador).
  Map<String, dynamic> toDraftJson() => {
        'idSitio': idSitio,
        'nombreSitio': nombreSitio,
        'descripcionMaterial': descripcionMaterial,
        'materialFaltante': materialFaltante,
        'descripcionFaltantes': descripcionFaltantes,
        'descripcionIncidencias': descripcionIncidencias,
        'tipos': tipos.toList(),
        'incidencias': incidencias.toList(),
      };

  bool get isNew => id == null;

  /// Copia editable detachada: el working se copia (independiente);
  /// El baseline se conserva (mismo punto de comparación) para que el diff siga válido tras editar.
  SitioDraft copy() => SitioDraft._(
        id: id,
        idSitio: idSitio,
        nombreSitio: nombreSitio,
        descripcionMaterial: descripcionMaterial,
        materialFaltante: materialFaltante,
        descripcionFaltantes: descripcionFaltantes,
        descripcionIncidencias: descripcionIncidencias,
        tipos: {...tipos},
        incidencias: {...incidencias},
        evidencias: evidencias.map((e) => e.copy()).toList(),
        tarimas: tarimas.map((t) => t.copy()).toList(),
        baselineIdSitio: _baselineIdSitio,
        baselineNombreSitio: _baselineNombreSitio,
        baselineDescripcionMaterial: _baselineDescripcionMaterial,
        baselineMaterialFaltante: _baselineMaterialFaltante,
        baselineDescripcionFaltantes: _baselineDescripcionFaltantes,
        baselineDescripcionIncidencias: _baselineDescripcionIncidencias,
        baselineTipos: _baselineTipos,
        baselineIncidencias: _baselineIncidencias,
        baselineEvidencias: _baselineEvidencias,
        baselineTarimas: _baselineTarimas,
      );

  /// True si el sitio (encabezado, hijos o tarimas) difiere de su
  /// baseline. Se usa para mandar a `sitiosEdit` solo lo que cambió.
  bool get hasChanges =>
      idSitio != _baselineIdSitio ||
      nombreSitio != _baselineNombreSitio ||
      descripcionMaterial != _baselineDescripcionMaterial ||
      materialFaltante != _baselineMaterialFaltante ||
      descripcionFaltantes != _baselineDescripcionFaltantes ||
      descripcionIncidencias != _baselineDescripcionIncidencias ||
      _tiposAdd.isNotEmpty ||
      _tiposDel.isNotEmpty ||
      _incidenciasAdd.isNotEmpty ||
      _incidenciasDel.isNotEmpty ||
      _evidenciasAdd.isNotEmpty ||
      _evidenciasEdit.isNotEmpty ||
      _evidenciasDel.isNotEmpty ||
      _tarimasChanged;

  /// Forma de creación / `sitiosAdd` (sin diff, todo el contenido).
  Map<String, dynamic> toCreateJson() => {
        'idSitio': idSitio,
        'nombreSitio': nombreSitio,
        'descripcionMaterial': descripcionMaterial,
        'materialFaltante': materialFaltante,
        'descripcionFaltantes': descripcionFaltantes,
        'descripcionIncidencias': descripcionIncidencias,
        'tiposMaterial': tipos.toList(),
        'incidencias': incidencias.toList(),
        'evidencias': evidencias.map((e) => e.toAddJson()).toList(),
        'tarimas': tarimas.map((t) => t.toJson()).toList(),
      };

  /// Forma de `sitiosEdit`: encabezado completo + diff de hijos.
  /// Tarimas van como **conjunto completo** (no diff): siempre se reenvían.
  Map<String, dynamic> toEditJson() => {
        'id': id,
        'idSitio': idSitio,
        'nombreSitio': nombreSitio,
        'descripcionMaterial': descripcionMaterial,
        'materialFaltante': materialFaltante,
        'descripcionFaltantes': descripcionFaltantes,
        'descripcionIncidencias': descripcionIncidencias,
        'tiposAdd': _tiposAdd,
        'tiposDel': _tiposDel,
        'incidenciasAdd': _incidenciasAdd,
        'incidenciasDel': _incidenciasDel,
        'evidenciasAdd': _evidenciasAdd,
        'evidenciasEdit': _evidenciasEdit,
        'evidenciasDel': _evidenciasDel,
        'tarimas': tarimas.map((t) => t.toJson()).toList(),
      };

  List<int> get _tiposAdd => tipos.difference(_baselineTipos).toList();
  List<int> get _tiposDel => _baselineTipos.difference(tipos).toList();
  List<int> get _incidenciasAdd => incidencias.difference(_baselineIncidencias).toList();
  List<int> get _incidenciasDel => _baselineIncidencias.difference(incidencias).toList();

  List<Map<String, dynamic>> get _evidenciasAdd =>
      evidencias.where((e) => e.id == null).map((e) => e.toAddJson()).toList();

  List<int> get _evidenciasDel {
    final currentIds = evidencias.map((e) => e.id).whereType<int>().toSet();
    return _baselineEvidencias.map((e) => e.id).whereType<int>().where((id) => !currentIds.contains(id)).toList();
  }

  List<Map<String, dynamic>> get _evidenciasEdit {
    final baseById = {
      for (final e in _baselineEvidencias)
        if (e.id != null) e.id!: e
    };
    return evidencias
        .where((e) => e.id != null && baseById.containsKey(e.id) && !e.sameAs(baseById[e.id]!))
        .map((e) => e.toEditJson())
        .toList();
  }

  /// Conjunto completo → "cambió" si difiere del baseline o hay foto pendiente.
  bool get _tarimasChanged {
    if (tarimas.length != _baselineTarimas.length) return true;
    for (var i = 0; i < tarimas.length; i++) {
      final t = tarimas[i];
      if (t.tarimaLocalPath != null || t.papeletaLocalPath != null) return true;
      if (!t.sameAs(_baselineTarimas[i])) return true;
    }
    return false;
  }
}
