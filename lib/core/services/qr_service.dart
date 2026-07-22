import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrService {
  final int version = QrVersions.auto;
  final int errorCorrectionLevel = QrErrorCorrectLevel.H;
  final QrEyeStyle eyeStyle = QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black);
  final QrDataModuleStyle dataModuleStyle = QrDataModuleStyle(
    dataModuleShape: QrDataModuleShape.square,
    color: Colors.black,
  );

  /// Retorna Uint8List con los bytes PNG del QR
  Future<Uint8List> generateQrBytes(String data, {int size = 512}) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: version,
        errorCorrectionLevel: errorCorrectionLevel,
      );

      if (!qrValidationResult.isValid) throw Exception('Datos inválidos para QR: ${qrValidationResult.error}');

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(qr: qrCode, eyeStyle: eyeStyle, gapless: true, dataModuleStyle: dataModuleStyle);
      final picData = await painter.toImageData(size.toDouble(), format: ui.ImageByteFormat.png);

      if (picData == null) throw Exception('Error al generar imagen del QR');

      return picData.buffer.asUint8List();
    } catch (e) {
      throw Exception('Error generando QR Bytes: $e');
    }
  }

  /// Retorna un Widget QrImageView
  Widget generateQrWidget({required String data, double size = 200.0}) {
    return QrImageView(
      data: data,
      version: version,
      size: size,
      backgroundColor: Colors.white,
      padding: EdgeInsets.all(16.0),
      eyeStyle: eyeStyle,
      dataModuleStyle: dataModuleStyle,
      errorCorrectionLevel: errorCorrectionLevel,
    );
  }

  /// Permite mostrar un dialog con QR
  /// [data] es lo que se codifica en el QR (p. ej. el deep link) y [label] lo
  /// que se muestra debajo (p. ej. el folio). Si no se pasa [label], se
  /// muestra [data].
  Future<void> showQRDialog(
    BuildContext context,
    String data,
    FutureOr<void> Function() onClose, {
    String? label,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              constraints: BoxConstraints(maxWidth: 350, minWidth: 350),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: const Text('QR generado')),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              content: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  generateQrWidget(data: data, size: 250),
                  Text(
                    label ?? data,
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'SF-Pro-Rounded-Regular'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(onClose);
  }
}
