// ignore_for_file: constant_identifier_names
import 'dart:convert';

/// Claves de la cabecera tal cual las devuelve el BFF (`/search` y `/{folio}`).
///
/// PascalCase salvo `nDocumentos` (así viaja en el JSON del listado) y `documentos`
/// (bucket de cabecera, solo en el detalle). `Sitios` legacy pasó a **`sitios`** (minúscula):
///   así lo emite el BFF SaaS en ambos endpoints.
enum EMaterialLogistics {
  Id,
  Folio,
  IdUsuario,
  Responsable,
  Correo,
  Fecha,
  IdXdock,
  Xdock,
  NombreResponsable,
  UnidadPlaca,
  NombreOperador,
  HoraLlegada,
  HoraInicioDescarga,
  HoraSalida,
  Confirmado,
  FechaCreacion,
  FechaEdicion,
  RE,
  IdCarrier,
  Carrier,
  EsOtro,
  OtroCarrier,
  Vinculado,
  nDocumentos,
  documentos,
  sitios,
}

/// Claves del sitio (camelCase, tal cual el JSON anidado).
/// El listado (`/search`) trae **solo resumen** (`materialFaltante` + los `n*`);
/// el detalle (`/{folio}`) trae además los arreglos completos.
enum ELogisticsSite {
  id,
  idSitio,
  nombreSitio,
  descripcionMaterial,
  materialFaltante,
  descripcionFaltantes,
  descripcionIncidencias,
  // Resumen (solo en /search)
  nIncidencias,
  nEvidencias,
  nTarimas,
  // Completo (solo en /{folio})
  tiposMaterial,
  incidencias,
  evidencias,
  tarimas,
}

// Coerciones tolerantes (mismo criterio que material_validation):
//    un `bit` SQL puede llegar como 0/1, y las columnas numéricas como string;
//    nada de esto debe tumbar el parseo ni depender de que el BFF acierte el tipo exacto.

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Acepta true / 1 / '1' / 'true'.
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

/// Decodifica un campo que puede llegar como `null`, `List` ya parseada, o `String` JSON.
/// Tolerante a ambas formas: el contrato dice que `sitios`/hijos ya vienen parseados,
/// pero si algún nivel llegara como string se decodifica.
List<dynamic> _asList(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value;
  if (value is String) {
    if (value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }
  return const [];
}

String _key(EMaterialLogistics e) => e.name;
String _keyS(ELogisticsSite e) => e.name;

/// Cabecera de Logística de Material — un arribo de XDOCK repartido en N sitios.
/// Recepción (`re == true`) / Entrega (`re == false`).
class MaterialLogistics {
  final int id;
  final String folio;
  final int? idUsuario; // dueño; base del gate de edición (`isOwnedBy`)
  final String responsable;
  final String correo;
  final String fecha;
  final int idXdock;
  final String xdock;
  final String? nombreResponsable; // null = el responsable es el usuario
  final String unidadPlaca;
  final String nombreOperador;
  final String horaLlegada;
  final String horaInicioDescarga;
  final String horaSalida;
  final bool confirmado;
  final String fechaCreacion;
  final String? fechaEdicion;
  final bool re; // true = Recepción, false = Entrega (inmutable en edición)
  final int idCarrier;
  final String carrier;
  final bool esOtro; // el carrier elegido es "Otro" (dato del catálogo, no id fijo)
  final String? otroCarrier;
  final int? vinculado; // Id del vínculo a Validación de Material, o null
  final int nDocumentos; // conteo de documentos de cabecera (en /search)
  final List<dynamic> documentos; // bucket de cabecera completo (solo en /{folio})
  final List<LogisticsSite> sitios;

  MaterialLogistics({
    required this.id,
    required this.folio,
    required this.idUsuario,
    required this.responsable,
    required this.correo,
    required this.fecha,
    required this.idXdock,
    required this.xdock,
    required this.nombreResponsable,
    required this.unidadPlaca,
    required this.nombreOperador,
    required this.horaLlegada,
    required this.horaInicioDescarga,
    required this.horaSalida,
    required this.confirmado,
    required this.fechaCreacion,
    required this.fechaEdicion,
    required this.re,
    required this.idCarrier,
    required this.carrier,
    required this.esOtro,
    required this.otroCarrier,
    required this.vinculado,
    required this.nDocumentos,
    required this.documentos,
    required this.sitios,
  });

  /// True si `userId` es el dueño (creador) del registro. Base del gate de
  /// edición en la lista: se ve todo el tenant (Perm.R), pero solo el dueño
  /// edita (Perm.U). El server lo revalida (404 al no-dueño).
  bool isOwnedBy(int? userId) => idUsuario != null && userId != null && idUsuario == userId;

  factory MaterialLogistics.fromJson(Map<String, dynamic> json) => MaterialLogistics(
    id: _asInt(json[_key(EMaterialLogistics.Id)]) ?? 0,
    folio: _str(json[_key(EMaterialLogistics.Folio)]),
    idUsuario: _asInt(json[_key(EMaterialLogistics.IdUsuario)]),
    responsable: _str(json[_key(EMaterialLogistics.Responsable)]),
    correo: _str(json[_key(EMaterialLogistics.Correo)]),
    fecha: _str(json[_key(EMaterialLogistics.Fecha)]),
    idXdock: _asInt(json[_key(EMaterialLogistics.IdXdock)]) ?? 0,
    xdock: _str(json[_key(EMaterialLogistics.Xdock)]),
    nombreResponsable: _strN(json[_key(EMaterialLogistics.NombreResponsable)]),
    unidadPlaca: _str(json[_key(EMaterialLogistics.UnidadPlaca)]),
    nombreOperador: _str(json[_key(EMaterialLogistics.NombreOperador)]),
    horaLlegada: _str(json[_key(EMaterialLogistics.HoraLlegada)]),
    horaInicioDescarga: _str(json[_key(EMaterialLogistics.HoraInicioDescarga)]),
    horaSalida: _str(json[_key(EMaterialLogistics.HoraSalida)]),
    confirmado: _asBool(json[_key(EMaterialLogistics.Confirmado)]),
    fechaCreacion: _str(json[_key(EMaterialLogistics.FechaCreacion)]),
    fechaEdicion: _strN(json[_key(EMaterialLogistics.FechaEdicion)]),
    re: _asBool(json[_key(EMaterialLogistics.RE)]),
    idCarrier: _asInt(json[_key(EMaterialLogistics.IdCarrier)]) ?? 0,
    carrier: _str(json[_key(EMaterialLogistics.Carrier)]),
    esOtro: _asBool(json[_key(EMaterialLogistics.EsOtro)]),
    otroCarrier: _strN(json[_key(EMaterialLogistics.OtroCarrier)]),
    vinculado: _asInt(json[_key(EMaterialLogistics.Vinculado)]),
    nDocumentos: _asInt(json[_key(EMaterialLogistics.nDocumentos)]) ?? 0,
    documentos: _asList(json[_key(EMaterialLogistics.documentos)]),
    sitios: _asList(
      json[_key(EMaterialLogistics.sitios)],
    ).whereType<Map>().map((e) => LogisticsSite.fromJson(e.cast<String, dynamic>())).toList(),
  );
}

/// Detalle/resumen por sitio. `idSitio`/`nombreSitio` de-normalizados (sin catálogo).
/// `id` es el `IdLogisticaSitio` (llave de fila) para el emparejamiento del diff;
/// `idSitio` es dato, no llave.
///
/// **Dos shapes según origen:**
///  - `/search` (resumen): `materialFaltante` + `nIncidencias`/`nEvidencias`/`nTarimas`;
///    los arreglos llegan vacíos.
///  - `/{folio}` (completo): además `descripcion*` y los arreglos
///    `tiposMaterial`/`incidencias`/`evidencias`/`tarimas`.
///
/// Los getters `count*` sirven ambos casos: usan el `n*` del resumen si vino, y si no, el largo del arreglo (detalle).
/// Así el listado pinta conteos sin pedir el detalle, y el detalle sigue funcionando con los arreglos.
class LogisticsSite {
  final int id;
  final String idSitio;
  final String nombreSitio;
  final String descripcionMaterial;
  final bool materialFaltante;
  final String? descripcionFaltantes;
  final String? descripcionIncidencias;

  // Resumen (/search). -1 = ausente (usa el largo del arreglo).
  final int _nIncidencias;
  final int _nEvidencias;
  final int _nTarimas;

  // Completo (/{folio}).
  final List<dynamic> tiposMaterial; // [{ id, idTipo, tipo }]
  final List<dynamic> incidencias; // [{ id, idTipo, tipo }]
  final List<dynamic> evidencias; // [{ id, idTipo, tipo, archivo, mimeType, orden }]
  final List<dynamic> tarimas; // [{ id, tarimaFoto, papeletaFoto, orden }]

  LogisticsSite({
    required this.id,
    required this.idSitio,
    required this.nombreSitio,
    required this.descripcionMaterial,
    required this.materialFaltante,
    required this.descripcionFaltantes,
    required this.descripcionIncidencias,
    required int nIncidencias,
    required int nEvidencias,
    required int nTarimas,
    required this.tiposMaterial,
    required this.incidencias,
    required this.evidencias,
    required this.tarimas,
  }) : _nIncidencias = nIncidencias,
       _nEvidencias = nEvidencias,
       _nTarimas = nTarimas;

  /// Conteos que sirven listado (resumen) y detalle (arreglos) de forma uniforme.
  int get countIncidencias => _nIncidencias >= 0 ? _nIncidencias : incidencias.length;
  int get countEvidencias => _nEvidencias >= 0 ? _nEvidencias : evidencias.length;
  int get countTarimas => _nTarimas >= 0 ? _nTarimas : tarimas.length;

  factory LogisticsSite.fromJson(Map<String, dynamic> json) => LogisticsSite(
    id: _asInt(json[_keyS(ELogisticsSite.id)]) ?? 0,
    idSitio: _str(json[_keyS(ELogisticsSite.idSitio)]),
    nombreSitio: _str(json[_keyS(ELogisticsSite.nombreSitio)]),
    descripcionMaterial: _str(json[_keyS(ELogisticsSite.descripcionMaterial)]),
    materialFaltante: _asBool(json[_keyS(ELogisticsSite.materialFaltante)]),
    descripcionFaltantes: _strN(json[_keyS(ELogisticsSite.descripcionFaltantes)]),
    descripcionIncidencias: _strN(json[_keyS(ELogisticsSite.descripcionIncidencias)]),
    nIncidencias: _asInt(json[_keyS(ELogisticsSite.nIncidencias)]) ?? -1,
    nEvidencias: _asInt(json[_keyS(ELogisticsSite.nEvidencias)]) ?? -1,
    nTarimas: _asInt(json[_keyS(ELogisticsSite.nTarimas)]) ?? -1,
    tiposMaterial: _asList(json[_keyS(ELogisticsSite.tiposMaterial)]),
    incidencias: _asList(json[_keyS(ELogisticsSite.incidencias)]),
    evidencias: _asList(json[_keyS(ELogisticsSite.evidencias)]),
    tarimas: _asList(json[_keyS(ELogisticsSite.tarimas)]),
  );
}
