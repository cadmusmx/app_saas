// ignore_for_file: constant_identifier_names
import 'dart:convert';

enum MaterialValidationSPKeys {
  warehousesMV,
  projectsMV,
  materialTypesMV,
  reasonsVM,
  carriersVM,
  physicalStatusVM,
}

enum EMaterialValidation {
  Id,
  IdUsuario,
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
}

class MaterialValidation {
  final int id;
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

  MaterialValidation({
    required this.id,
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
  });

  factory MaterialValidation.fromJson(Map<String, dynamic> json) => MaterialValidation(
        id: json[EMaterialValidation.Id.name],
        folio: json[EMaterialValidation.Folio.name],
        responsable: json[EMaterialValidation.Responsable.name],
        idProyecto: json[EMaterialValidation.IdProyecto.name],
        proyecto: json[EMaterialValidation.Proyecto.name],
        idTipoMaterial: json[EMaterialValidation.IdTipoMaterial.name],
        nombreSitio: json[EMaterialValidation.NombreSitio.name],
        idSitio: json[EMaterialValidation.IdSitio.name],
        cuentaCliente: json[EMaterialValidation.CuentaCliente.name],
        fecha: json[EMaterialValidation.Fecha.name],
        aspNombre: json[EMaterialValidation.AspNombre.name],
        aspFirma: json[EMaterialValidation.AspFirma.name],
        nombreContacto: json[EMaterialValidation.NombreContacto.name],
        idCarrier: json[EMaterialValidation.IdCarrier.name],
        carrier: json[EMaterialValidation.Carrier.name],
        otroCarrier: json[EMaterialValidation.OtroCarrier.name],
        idRegion: json[EMaterialValidation.IdRegion.name],
        almacenDestino: json[EMaterialValidation.AlmacenDestino.name],
        idAlmacenDestino: json[EMaterialValidation.IdAlmacenDestino.name],
        totalPiezas: json[EMaterialValidation.TotalPiezas.name],
        placasTransporte: json[EMaterialValidation.PlacasTransporte.name],
        piezasMotivo: jsonDecode(json[EMaterialValidation.PiezasMotivo.name] ?? '[]'),
        piezasEstadoF: jsonDecode(json[EMaterialValidation.PiezasEstadoF.name] ?? '[]'),
        documentos: jsonDecode(json[EMaterialValidation.MaterialDocumentos.name] ?? '[]'),
        materialEnTransporteFoto: json[EMaterialValidation.MaterialEnTransporteFoto.name],
        materialDescargadoFoto: json[EMaterialValidation.MaterialDescargadoFoto.name],
        transporteFoto: json[EMaterialValidation.TransporteFoto.name],
        placasFoto: json[EMaterialValidation.PlacasFoto.name],
        notas: json[EMaterialValidation.Notas.name] ?? '',
        qr: json[EMaterialValidation.Qr.name],
        fechaCaptura: json[EMaterialValidation.FechaCaptura.name] ?? '',
        tipoMaterial: json[EMaterialValidation.TipoMaterial.name],
        status: json[EMaterialValidation.Status.name],
        es: json[EMaterialValidation.ES.name],
        fechaEdicion: json[EMaterialValidation.FechaEdicion.name],
        numTarimas: json[EMaterialValidation.NumTarimas.name],
        tarimas: jsonDecode(json[EMaterialValidation.Tarimas.name] ?? '{}'),
        cancelada: json[EMaterialValidation.Cancelada.name],
      );
}
