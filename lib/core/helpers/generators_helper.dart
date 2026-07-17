import 'dart:convert';
import 'dart:typed_data';
import 'package:signature/signature.dart';

/// Permite generar un código de 6 caracteres aleatorios
String generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ123456789';
  final buffer = StringBuffer();
  for (int i = 0; i < 6; i++) {
    buffer.write(chars[(DateTime.now().microsecondsSinceEpoch + i * 37) % chars.length]);
  }
  return buffer.toString();
}

/// obtiene la lista Uint8List de la firma SignatureController o null si es una edición y hay una existente (existing)
Future<String?> encodeFirma(SignatureController controller, bool isEdition, {required Uint8List? existing}) async {
  // Si está en edición y ya hay firma previa, no hace falta regenerarla
  if (isEdition && existing != null) return null;
  final pngBytes = await controller.toPngBytes();
  if (pngBytes == null || pngBytes.isEmpty) return null;
  return base64Encode(pngBytes);
}

/// Genera un folio único con información util.
String getFolio(String idUsuario, String prefix) {
  final id = int.tryParse(idUsuario);
  if (id == null || id < 0 || id > 1048575) throw ArgumentError('Id no valido para el folio');
  final hexId = id.toRadixString(16).toUpperCase().padLeft(5, '0');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final hexTS = timestamp.toRadixString(16).toUpperCase();
  return '$prefix$hexId$hexTS';
}
