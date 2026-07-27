// ignore_for_file: constant_identifier_names
import 'dart:convert';

enum MaterialLogisticsSPKeys {
  xdocksML,
  materialTypesML,
  incidenceTypesML,
  evidenceTypesML,
  carriersML,
}

/// Claves de la cabecera (PascalCase, tal cual las devuelve `sp_LM_GetByFolio` / `sp_LM_GetList`).
/// A diferencia de `EMaterialReceived`, la cabecera ya NO lleva los 4 campos descriptivos (bajaron al sitio) y suma `Sitios`.
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
  OtroCarrier,
  Sitios,
}

/// Claves del sitio (camelCase, tal cual el JSON anidado del SP).
enum ELogisticsSite {
  id,
  idSitio,
  nombreSitio,
  descripcionMaterial,
  materialFaltante,
  descripcionFaltantes,
  descripcionIncidencias,
  tiposMaterial,
  incidencias,
  evidencias,
  tarimas,
}

/// Decodifica un campo que puede llegar como:
/// - `null`            -> lista vacía
/// - `List` ya parseada -> se usa tal cual (caso `JSON_QUERY` anidado del SP, o
///                         si el backend lo pre-parsea)
/// - `String` JSON      -> se decodifica una vez (caso del nivel `Sitios`)
///
/// Tolera ambas formas a propósito: el contrato sugiere `jsonDecode` por sitio,
/// pero `sp_LM_GetByFolio` ya entrega los hijos anidados como arreglos.
List<dynamic> _asList(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value;
  if (value is String) {
    if (value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    return decoded is List ? decoded : const [];
  }
  return const [];
}

/// Cabecera de Logística de Material — un arribo de XDOCK repartido en N sitios.
/// Recepción (`re == true`) / Entrega (`re == false`).
class MaterialLogistics {
  final int id;
  final String folio;
  final int idUsuario;
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
  final String? otroCarrier;
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
    required this.otroCarrier,
    required this.sitios,
  });

  factory MaterialLogistics.fromJson(Map<String, dynamic> json) => MaterialLogistics(
        id: json[EMaterialLogistics.Id.name] ?? 0,
        folio: json[EMaterialLogistics.Folio.name] ?? '',
        idUsuario: json[EMaterialLogistics.IdUsuario.name] ?? 0,
        responsable: json[EMaterialLogistics.Responsable.name] ?? '',
        correo: json[EMaterialLogistics.Correo.name] ?? '',
        fecha: json[EMaterialLogistics.Fecha.name] ?? '',
        idXdock: json[EMaterialLogistics.IdXdock.name] ?? 0,
        xdock: json[EMaterialLogistics.Xdock.name] ?? '',
        nombreResponsable: json[EMaterialLogistics.NombreResponsable.name],
        unidadPlaca: json[EMaterialLogistics.UnidadPlaca.name] ?? '',
        nombreOperador: json[EMaterialLogistics.NombreOperador.name] ?? '',
        horaLlegada: json[EMaterialLogistics.HoraLlegada.name] ?? '',
        horaInicioDescarga: json[EMaterialLogistics.HoraInicioDescarga.name] ?? '',
        horaSalida: json[EMaterialLogistics.HoraSalida.name] ?? '',
        confirmado: json[EMaterialLogistics.Confirmado.name] ?? false,
        fechaCreacion: json[EMaterialLogistics.FechaCreacion.name] ?? '',
        fechaEdicion: json[EMaterialLogistics.FechaEdicion.name],
        re: json[EMaterialLogistics.RE.name] ?? true,
        idCarrier: json[EMaterialLogistics.IdCarrier.name] ?? 1,
        carrier: json[EMaterialLogistics.Carrier.name] ?? '',
        otroCarrier: json[EMaterialLogistics.OtroCarrier.name],
        sitios: _asList(json[EMaterialLogistics.Sitios.name])
            .whereType<Map<String, dynamic>>()
            .map(LogisticsSite.fromJson)
            .toList(),
      );
}

/// Detalle por sitio. `idSitio`/`nombreSitio` están de-normalizados (sin catálogo).
/// `id` es el `IdLogisticaSitio` (llave de fila) usado para el emparejamiento en el diff de edición;
/// `idSitio` es dato, no llave.
class LogisticsSite {
  final int id;
  final String idSitio;
  final String nombreSitio;
  final String descripcionMaterial;
  final bool materialFaltante;
  final String? descripcionFaltantes;
  final String? descripcionIncidencias;
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
    required this.tiposMaterial,
    required this.incidencias,
    required this.evidencias,
    required this.tarimas,
  });

  factory LogisticsSite.fromJson(Map<String, dynamic> json) => LogisticsSite(
        id: json[ELogisticsSite.id.name] ?? 0,
        idSitio: json[ELogisticsSite.idSitio.name] ?? '',
        nombreSitio: json[ELogisticsSite.nombreSitio.name] ?? '',
        descripcionMaterial: json[ELogisticsSite.descripcionMaterial.name] ?? '',
        materialFaltante: json[ELogisticsSite.materialFaltante.name] ?? false,
        descripcionFaltantes: json[ELogisticsSite.descripcionFaltantes.name],
        descripcionIncidencias: json[ELogisticsSite.descripcionIncidencias.name],
        tiposMaterial: _asList(json[ELogisticsSite.tiposMaterial.name]),
        incidencias: _asList(json[ELogisticsSite.incidencias.name]),
        evidencias: _asList(json[ELogisticsSite.evidencias.name]),
        tarimas: _asList(json[ELogisticsSite.tarimas.name]),
      );
}
