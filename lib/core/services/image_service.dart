import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageService {
  /// Formato de salida de [waterMarkImage]. La codificación es SIEMPRE PNG,
  /// así que estas constantes son la única fuente de verdad para los callers.
  static const String watermarkExtension = 'png';
  static const String watermarkMimeType = 'image/png';

  /// Extensiones de imagen admitidas como entrada.
  static const Set<String> _supportedImageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'};

  /// Aplica una marca de agua sobre [pickedFile] y devuelve un PNG en disco.
  ///
  /// Valida que la entrada sea una imagen soportada antes de procesar.
  /// Lanza [FormatException] si el archivo no es una imagen válida o no se
  /// puede decodificar. El archivo devuelto siempre tiene extensión .png
  /// (ver [watermarkExtension] / [watermarkMimeType]).
  Future<File> waterMarkImage(XFile pickedFile, String watermark) async {
    // 1. Validación de tipo de entrada (extensión, con respaldo en mimeType).
    final inputExt = _imageExtensionOf(pickedFile);
    if (!_supportedImageExtensions.contains(inputExt)) {
      throw FormatException('El archivo seleccionado no es una imagen soportada (.$inputExt).');
    }

    // 2. Decodificación con guarda: extensión válida no garantiza bytes válidos.
    final Uint8List originalBytes = await pickedFile.readAsBytes();
    late final ui.Image original;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(originalBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      original = frame.image;
      codec.dispose();
    } catch (e) {
      throw FormatException('No se pudo decodificar la imagen: $e');
    }

    // 3. Render de la imagen + marca de agua sobre un canvas.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(original, Offset.zero, Paint());

    final double fontSize = original.width * 0.035;
    final textStyle = TextStyle(
      color: Colors.yellow,
      backgroundColor: Colors.black.withAlpha(100),
      fontSize: fontSize,
      fontFamily: 'SF-Pro-Rounded-Regular',
    );

    final List<String> phrases = watermark.split('\n');
    int i = 1;
    for (final phrase in phrases.reversed) {
      final textSpan = TextSpan(text: phrase, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      final double x = original.width - textPainter.width - 20;
      final double y = original.height - (textPainter.height * i) - 20;
      textPainter.paint(canvas, Offset(x, y));
      i++;
    }

    // 4. Exportar a PNG (liberando los recursos nativos en el camino).
    final ui.Picture picture = recorder.endRecording();
    final ui.Image finalImage = await picture.toImage(original.width, original.height);
    picture.dispose();
    original.dispose();

    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    finalImage.dispose();
    if (byteData == null) {
      throw const FormatException('No se pudo codificar la imagen con marca de agua.');
    }
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    // 5. Escribir en disco con la extensión correcta garantizada.
    final dir = await getApplicationDocumentsDirectory();
    final outputFile = File('${dir.path}/watermark_${DateTime.now().millisecondsSinceEpoch}.$watermarkExtension');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(pngBytes, flush: true);

    return outputFile;
  }

  /// Deduce la extensión de imagen de un [XFile]: primero por la ruta y,
  /// si no tiene, por el mimeType (p. ej. 'image/jpeg' -> 'jpeg').
  String _imageExtensionOf(XFile file) {
    final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
    if (ext.isNotEmpty) return ext;
    final mime = file.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime.split('/').last.toLowerCase();
    return '';
  }

  Widget Function(double, File?, bool?) imagePreview = (size, image, loading) {
    return loading != null && loading
        ? Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(16),
            color: Colors.grey,
            child: const CircularProgressIndicator(),
          )
        : image != null
            ? Image.file(image, width: size, height: size, fit: BoxFit.cover)
            : Container(width: size, height: size, color: Colors.grey.shade300, child: const Icon(Icons.camera_alt));
  };
}
