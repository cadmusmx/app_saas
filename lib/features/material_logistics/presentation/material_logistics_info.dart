import 'package:gaso_tenant_app/core/widgets/info/info_letter.dart';

const materialLogisticsLetter = InfoLetter(
  title: 'Logística',
  summary: 'Varios Sitios, XDOCK, Control de arribo',
  sections: [
    InfoLetterSection.text('Propósito',
        'Registra la recepción o entrega de un arribo por XDOCK. Un mismo arribo puede repartirse en varios sitios, y cada sitio lleva su propio detalle de material, tiempos, faltantes, incidencias y evidencias.'),
    InfoLetterSection.text('Qué necesitas a la mano',
        'Fecha y XDOCK, carrier, datos del operador y la unidad (placas), y los horarios de llegada, inicio de descarga y salida.'),
    InfoLetterSection.bullets('Reglas clave', [
      'Captura al menos un sitio; el sitio se escribe a mano con formato Id-Nombre (ej. 12A-NORTE).',
      'Por cada sitio: descripción del material, ≥1 tipo de material y ≥1 evidencia.',
      'Si hay material faltante, describe qué falta.',
      'Las tarimas son opcionales (hasta 50 por sitio) y cada una requiere foto de tarima y de papeleta.',
    ]),
  ],
);
