// ignore_for_file: constant_identifier_names
import 'dart:convert';

/// Nombres de columna de la cabecera **tal cual los emite la DB/BFF** (`/search` y `/{folio}` devuelven PascalCase).
/// Confirmado: `ES` y `OtroCarrier` viajan con ese nombre exacto.
///
/// El *valor* sí se coerciona defensivamente: un `bit` SQL puede llegar como `1/0` en vez de `true/false`
/// (mismo motivo por el que `session_user` usa `_asBool` para `isActive`), y las columnas nullable no deben tumbar el parseo.
///
/// El enum legacy `MaterialValidationSPKeys` se eliminó: los catálogos ya no se cachean por spKey global (viven en `MaterialCatalogsCache`).
enum EMaterialValidation {
  Id,
  IdUsuario, // dueño del registro (solo lectura; gatea la edición por pertenencia)
  Folio,
  Responsable,
  IdProyecto,
  Proyecto,
  IdTipoMaterial,
  TipoMaterial,
  NombreSitio,
  IdSitio,
  CuentaCliente,
  Fecha,
  AspNombre,
  AspFirma,
  NombreContacto,
  IdCarrier,
  Carrier,
  OtroCarrier,
  IdRegion,
  AlmacenDestino,
  IdAlmacenDestino,
  TotalPiezas,
  PlacasTransporte,
  MaterialEnTransporteFoto,
  MaterialDescargadoFoto,
  TransporteFoto,
  PlacasFoto,
  Notas,
  Qr,
  FechaCaptura,
  FechaEdicion,
  PiezasMotivo,
  PiezasEstadoF,
  MaterialDocumentos,
  Status,
  ES,
  NumTarimas,
  Tarimas,
  Cancelada,
  Vinculado, // Id del vínculo o null (viene en /search y /{folio})
}

class MaterialValidation {
  final int id;

  /// Dueño del registro (columna `IdUsuario`). **Solo lectura**:
  ///   se usa para mostrar *Editar* únicamente al dueño (misma regla que legacy).
  /// NO se envía en payloads: la identidad del actor sale del token.
  final int? idUsuario;
  final String folio;
  final String responsable; // Quien recibe/entrega GASO
  final int idProyecto;
  final int idTipoMaterial;
  final String nombreSitio; // nombre del proyecto o sitio
  final String idSitio;
  final String cuentaCliente;
  final String fecha; // fecha de devolución/entrada/salida
  final String aspNombre;
  final String aspFirma;
  final String nombreContacto; // nombre del contacto ERICSSON
  final int idCarrier;
  final String carrier;
  final String? otroCarrier;
  final int idRegion;
  final String almacenDestino; // almacén destino
  final int idAlmacenDestino; // almacén destino
  final int totalPiezas; // Total de piezas recibidas
  final String placasTransporte;
  final List<dynamic> piezasMotivo; // (lista/json) {id, cl, clt, pzs}
  final List<dynamic> piezasEstadoF; // (lista/json) {id, cl, clt, pzs}
  final List<dynamic> documentos;
  final String materialEnTransporteFoto; // foto del material como se transporta
  final String? materialDescargadoFoto; // foto del material ya abajo
  final String transporteFoto; // foto del camion
  final String placasFoto; // foto de las placas del camion
  final String notas; // observaciones y notas
  final String qr;
  final String fechaCaptura;
  final String proyecto;
  final String tipoMaterial;
  final int status;
  final bool es;
  final String? fechaEdicion;
  final int numTarimas;
  final Map<String, dynamic> tarimas;
  final bool cancelada;

  /// Id del vínculo o `null`. Permite saber si el folio ya está vinculado sin pegarle a `GET /linked` (el server ya lo trae en `/search` y `/{folio}`).
  final int? vinculado;

  MaterialValidation({
    required this.id,
    required this.idUsuario,
    required this.folio,
    required this.responsable,
    required this.idProyecto,
    required this.idTipoMaterial,
    required this.nombreSitio,
    required this.idSitio,
    required this.cuentaCliente,
    required this.fecha,
    required this.aspNombre,
    required this.aspFirma,
    required this.nombreContacto,
    required this.idCarrier,
    required this.carrier,
    required this.otroCarrier,
    required this.idRegion,
    required this.almacenDestino,
    required this.idAlmacenDestino,
    required this.totalPiezas,
    required this.placasTransporte,
    required this.piezasMotivo,
    required this.piezasEstadoF,
    required this.documentos,
    required this.materialEnTransporteFoto,
    required this.materialDescargadoFoto,
    required this.transporteFoto,
    required this.placasFoto,
    required this.notas,
    required this.qr,
    required this.fechaCaptura,
    required this.proyecto,
    required this.tipoMaterial,
    required this.status,
    required this.es,
    required this.fechaEdicion,
    required this.numTarimas,
    required this.tarimas,
    required this.cancelada,
    required this.vinculado,
  });

  /// `true` si el registro pertenece a [userId]. Base de la regla "solo el dueño edita" que consume la lista para mostrar/ocultar *Editar*.
  bool isOwnedBy(int? userId) => idUsuario != null && userId != null && idUsuario == userId;

  factory MaterialValidation.fromJson(Map<String, dynamic> json) {
    String k(EMaterialValidation e) => e.name;
    return MaterialValidation(
      id: _asInt(json[k(EMaterialValidation.Id)]) ?? 0,
      idUsuario: _asInt(json[k(EMaterialValidation.IdUsuario)]),
      folio: _str(json[k(EMaterialValidation.Folio)]),
      responsable: _str(json[k(EMaterialValidation.Responsable)]),
      idProyecto: _asInt(json[k(EMaterialValidation.IdProyecto)]) ?? 0,
      proyecto: _str(json[k(EMaterialValidation.Proyecto)]),
      idTipoMaterial: _asInt(json[k(EMaterialValidation.IdTipoMaterial)]) ?? 0,
      nombreSitio: _str(json[k(EMaterialValidation.NombreSitio)]),
      idSitio: _str(json[k(EMaterialValidation.IdSitio)]),
      cuentaCliente: _str(json[k(EMaterialValidation.CuentaCliente)]),
      fecha: _str(json[k(EMaterialValidation.Fecha)]),
      aspNombre: _str(json[k(EMaterialValidation.AspNombre)]),
      aspFirma: _str(json[k(EMaterialValidation.AspFirma)]),
      nombreContacto: _str(json[k(EMaterialValidation.NombreContacto)]),
      idCarrier: _asInt(json[k(EMaterialValidation.IdCarrier)]) ?? 0,
      carrier: _str(json[k(EMaterialValidation.Carrier)]),
      otroCarrier: _strN(json[k(EMaterialValidation.OtroCarrier)]),
      idRegion: _asInt(json[k(EMaterialValidation.IdRegion)]) ?? 0,
      almacenDestino: _str(json[k(EMaterialValidation.AlmacenDestino)]),
      idAlmacenDestino: _asInt(json[k(EMaterialValidation.IdAlmacenDestino)]) ?? 0,
      totalPiezas: _asInt(json[k(EMaterialValidation.TotalPiezas)]) ?? 0,
      placasTransporte: _str(json[k(EMaterialValidation.PlacasTransporte)]),
      piezasMotivo: _decodeList(json[k(EMaterialValidation.PiezasMotivo)]),
      piezasEstadoF: _decodeList(json[k(EMaterialValidation.PiezasEstadoF)]),
      documentos: _decodeList(json[k(EMaterialValidation.MaterialDocumentos)]),
      materialEnTransporteFoto: _str(json[k(EMaterialValidation.MaterialEnTransporteFoto)]),
      materialDescargadoFoto: _strN(json[k(EMaterialValidation.MaterialDescargadoFoto)]),
      transporteFoto: _str(json[k(EMaterialValidation.TransporteFoto)]),
      placasFoto: _str(json[k(EMaterialValidation.PlacasFoto)]),
      notas: _str(json[k(EMaterialValidation.Notas)]),
      qr: _str(json[k(EMaterialValidation.Qr)]),
      fechaCaptura: _str(json[k(EMaterialValidation.FechaCaptura)]),
      tipoMaterial: _str(json[k(EMaterialValidation.TipoMaterial)]),
      status: _asInt(json[k(EMaterialValidation.Status)]) ?? 0,
      es: _asBool(json[k(EMaterialValidation.ES)]),
      fechaEdicion: _strN(json[k(EMaterialValidation.FechaEdicion)]),
      numTarimas: _asInt(json[k(EMaterialValidation.NumTarimas)]) ?? 0,
      tarimas: _decodeMap(json[k(EMaterialValidation.Tarimas)]),
      cancelada: _asBool(json[k(EMaterialValidation.Cancelada)]),
      vinculado: _asInt(json[k(EMaterialValidation.Vinculado)]),
    );
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Acepta true / 1 / '1' / 'true' (un `bit` SQL puede llegar como 0/1).
bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v == 1;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true';
  }
  return false;
}

String _str(dynamic v) => v?.toString() ?? '';
String? _strN(dynamic v) => v?.toString();

/// `PiezasMotivo`/`PiezasEstadoF`/`MaterialDocumentos` llegan como **string JSON** (`FOR JSON PATH`).
/// Tolerante por si el BFF alguna vez los manda ya parseados.
List<dynamic> _decodeList(dynamic v) {
  if (v == null) return <dynamic>[];
  if (v is List) return List<dynamic>.from(v);
  if (v is String) {
    try {
      final d = jsonDecode(v.isEmpty ? '[]' : v);
      return d is List ? List<dynamic>.from(d) : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }
  return <dynamic>[];
}

Map<String, dynamic> _decodeMap(dynamic v) {
  if (v == null) return <String, dynamic>{};
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String) {
    try {
      final d = jsonDecode(v.isEmpty ? '{}' : v);
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  return <String, dynamic>{};
}
