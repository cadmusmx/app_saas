import 'dart:convert';
import 'dart:typed_data';
import 'package:signature/signature.dart';

class SignatureValidator {
  /// Verifica si la firma está presente (nueva o existente)
  static bool isSigned(SignatureController controller, Uint8List? existing) {
    return existing != null || controller.isNotEmpty;
  }

  /// Verifica si la firma es válida (suficientes puntos)
  static bool isValid(SignatureController controller, Uint8List? existing, {int minPoints = 50}) {
    if (existing != null) return true;
    return controller.points.length >= minPoints;
  }

  /// Codifica la firma a Base64 (solo si cambió)
  static Future<String?> encode(SignatureController controller, bool isEdition, {Uint8List? existing}) async {
    // En edición, si no cambió, retornar null
    if (isEdition && existing != null && controller.isEmpty) {
      return null;
    }
    if (controller.isEmpty) return null;
    final signature = await controller.toPngBytes();
    if (signature == null) return null;
    return base64Encode(signature);
  }

  /// Valida múltiples firmas
  static bool validateMultiple(List<SignatureController> controllers, List<Uint8List?> existingSignatures,
      {int minPoints = 50}) {
    if (controllers.length != existingSignatures.length) return false;
    for (int i = 0; i < controllers.length; i++) {
      if (!isSigned(controllers[i], existingSignatures[i])) return false;
      if (!isValid(controllers[i], existingSignatures[i], minPoints: minPoints)) {
        return false;
      }
    }
    return true;
  }
}
