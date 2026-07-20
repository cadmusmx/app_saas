enum ProfileSPKeys { activeUsersP }

enum EUserDataUpdate {
  idusuario,
  nombre,
  usuario,
  correo,
  password,
  idperfil,
  idsuperior,
  idregion,
  idciudadbase,
  idtiposangre,
  tienelicencia,
  fechalicencia,
  fechadc3,
  fechanacimiento,
  sueldo,
  idarea,
  iddepartamento,
  telefono,
  correopersonal,
  contactoemergencia,
  numcelularsecundario,
  curp,
  rfc,
  fechaalta,
  nss,
}

enum EFamilyContactUpdate {
  nombreContacto1,
  telefonoContacto1,
  idparentesco1,
  nombreContacto2,
  telefonoContacto2,
  idparentesco2,
}

enum EDocumentTypes {
  ine,
  curp,
  actaNacimiento,
  nss,
  csFiscal,
  comprobanteDomicilio,
  uGEstudios,
  eCBancaria,
  licenciaConducir,
  fotoDigital,
  certificadoMedico,
  otro,
}
class FamilyContact {
  int? contactId;
  int parentId;
  String parentName;
  String contactNumber;

  FamilyContact({this.contactId, required this.parentId, required this.parentName, required this.contactNumber});
}

class UserDocuments {
  String? ine;
  String? curp;
  String? actaNacimiento;
  String? nss;
  String? csFiscal;
  String? comprobanteDomicilio;
  String? ugEstudios;
  String? ecBancaria;
  String? licenciaConducir;
  String? fotoDigital;
  String? certificadoMedico;
  String? fotoPerfil;
  String? bajaIMSS;
  String? otro;
  String? acuerdoConfidencial;

  UserDocuments(
      {this.ine,
      this.curp,
      this.actaNacimiento,
      this.nss,
      this.csFiscal,
      this.comprobanteDomicilio,
      this.ugEstudios,
      this.ecBancaria,
      this.licenciaConducir,
      this.fotoDigital,
      this.certificadoMedico,
      this.fotoPerfil,
      this.bajaIMSS,
      this.otro,
      this.acuerdoConfidencial});

  factory UserDocuments.fromJson(Map<String, dynamic> json) => UserDocuments(
        ine: json['Ine'],
        curp: json['Curp'],
        actaNacimiento: json['ActaNacimiento'],
        nss: json['NSS'],
        csFiscal: json['CSFiscal'],
        comprobanteDomicilio: json['ComprobanteDomicilio'],
        ugEstudios: json['UGEstudios'],
        ecBancaria: json['ECBancaria'],
        licenciaConducir: json['LicenciaConducir'],
        fotoDigital: json['FotoDigital'],
        certificadoMedico: json['CertificadoMedico'],
        fotoPerfil: json['FotoPerfil'],
        bajaIMSS: json['BAjaIMSS'],
        otro: json['Otro'],
        acuerdoConfidencial: json['AcuerdoConfidencial'],
      );
}
