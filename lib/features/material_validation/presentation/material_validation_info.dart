import 'package:gaso_tenant_app/core/widgets/info/info_letter.dart';

const materialValidationLetter = InfoLetter(
  title: 'Validación',
  summary: 'Un Sitio, Proyecto, Tipo de material, ASP - Genera QR.',
  sections: [
    InfoLetterSection.text('Propósito',
        'Registra la entrada o salida de material de un sitio, dejando constancia del material, su estado.'),
    InfoLetterSection.text('Qué necesitas a la mano',
        'Proyecto y tipo de material, cuenta cliente, firma ASP, contacto, almacén, carrier, datos del transporte y las evidencias correspondientes.'),
    InfoLetterSection.bullets('Reglas clave', [
      'Debes registrar al menos una de estas tres: piezas, documentos o tarimas.',
      'La firma del ASP es obligatoria y debe tener cierto detalle.',
      'Si el folio ya está vinculado a un proceso de logística, no podrás cambiar el tipo Entrada/Salida.',
    ]),
    InfoLetterSection.text('Al guardar', 'Se genera un código QR del folio para dar seguimiento a la validación.'),
  ],
);
