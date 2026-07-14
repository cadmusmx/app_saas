import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;

class ImageService {
  /// Retorna un archivo en png con la marca de agua establecida
  Future<File> waterMarkImage(XFile pickedFile, String watermark) async {
    final Uint8List originalBytes = await pickedFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(originalBytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image original = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Dibuja la imagen original en el canvas
    final paint = Paint();
    canvas.drawImage(original, Offset.zero, paint);

    // Estilo del texto
    final double fontSize = original.width * 0.035;
    final textStyle = TextStyle(
        color: Colors.yellow,
        backgroundColor: Colors.black.withAlpha(100),
        fontSize: fontSize,
        fontFamily: 'SF-Pro-Rounded-Regular');

    List<String> phrases = watermark.split('\n');
    int i = 1;
    // Por cada "frase" > pinta en el canvas
    for (String phrase in phrases.reversed) {
      final textSpan = TextSpan(text: phrase, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();

      // posición (abajo a la derecha con margen de 20px)
      final double x = original.width - textPainter.width - 20;
      final double y = original.height - (textPainter.height * i) - 20;

      // Dibujar el texto
      textPainter.paint(canvas, Offset(x, y));
      i++;
    }

    // resultado a ui.Image
    final ui.Image finalImage = await recorder.endRecording().toImage(original.width, original.height);

    // Codificar a PNG
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    // Usar directorio de documentos en lugar de cache
    final dir = await getApplicationDocumentsDirectory();
    final outputFile = File('${dir.path}/watermark_${DateTime.now().millisecondsSinceEpoch}.png');

    // Asegurar que el directorio existe
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(pngBytes, flush: true);

    return outputFile;
  }
}
