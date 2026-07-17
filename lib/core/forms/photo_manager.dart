import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:gaso_tenant_app/core/widgets/forms/photo_upload.dart';
import 'package:gaso_tenant_app/core/services/s3_service.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';

/// Gestión unificada de fotografías con S3
class PhotoManager {
  final S3Service _s3Service;
  final int userId;
  final String photosFolder;

  PhotoManager({required S3Service s3Service, required this.userId, required this.photosFolder})
      : _s3Service = s3Service;

  /// Sube múltiples fotos a S3 (para formularios nuevos)
  Future<PhotoUploadResult> uploadPhotos(
    List<PhotoField> photos,
    String timestamp,
  ) async {
    final results = <String, String?>{};
    final errors = <String>[];

    for (var photo in photos) {
      if (photo.file != null) {
        try {
          Uint8List fileBytes = await photo.file!.readAsBytes();
          final extension = p.extension(photo.file!.path);
          final url = await uploadSingle(fileBytes, extension, photo.key, timestamp);
          results[photo.key] = url;
          if (url == null) {
            errors.add('Error al subir ${photo.label}');
          }
        } catch (e) {
          DebugLog.error('Error subiendo foto ${photo.key}: $e');
          errors.add('Error al subir ${photo.label}');
        }
      } else if (photo.url.isNotEmpty) {
        // Foto existente, mantener URL
        results[photo.key] = photo.url;
      }
    }

    return PhotoUploadResult(
      urls: results,
      hasErrors: errors.isNotEmpty,
      errors: errors,
    );
  }

  /// Procesa fotos editadas (sube nuevas, mantiene existentes, borra reemplazadas)
  Future<PhotoUploadResult> processEditedPhotos(
      List<PhotoField> photos, Map<String, dynamic> savedUrls, String timestamp) async {
    final results = <String, String?>{};
    final errors = <String>[];
    final toDelete = <String>[];
    for (var photo in photos) {
      final prevUrl = savedUrls[photo.key]?.toString();
      if (photo.file != null) {
        try {
          Uint8List fileBytes = await photo.file!.readAsBytes();
          final extension = p.extension(photo.file!.path);
          final newUrl = await uploadSingle(fileBytes, extension, photo.key, timestamp);
          results[photo.key] = newUrl;
          if (newUrl != null && prevUrl != null && prevUrl.isNotEmpty) {
            toDelete.add(prevUrl);
          } else if (newUrl == null) {
            errors.add('Error al subir ${photo.label}');
          }
        } catch (e) {
          DebugLog.error('Error procesando foto ${photo.key}: $e');
          errors.add('Error al procesar ${photo.label}');
        }
      } else if (photo.url.isNotEmpty) {
        // Mantener foto existente
        results[photo.key] = photo.url;
      } else if (prevUrl != null && prevUrl.isNotEmpty) {
        // Foto eliminada
        toDelete.add(prevUrl);
      }
    }
    // Eliminar fotos reemplazadas
    for (var url in toDelete) {
      try {
        await _s3Service.deleteFromS3(url);
      } catch (e) {
        DebugLog.warning('Error eliminando foto $url: $e');
      }
    }
    return PhotoUploadResult(
      urls: results,
      hasErrors: errors.isNotEmpty,
      errors: errors,
    );
  }

  /// Sube un archivo individual a S3
  Future<String?> uploadSingle(Uint8List fileBytes, String extension, String key, String timestamp) async {
    final fileName = '${key}_$timestamp$extension';
    final filePath = '$photosFolder$userId/$fileName';
    final contentType = extension.contains('png') ? 'image/png' : 'image/jpeg';
    final url = await _s3Service.uploadU8LToS3(fileBytes, filePath, contentType);
    return url != null ? filePath : null;
  }

  /// Valida que todas las fotos requeridas estén presentes
  bool validateRequiredPhotos(List<PhotoField> photos, {bool isEdition = false}) {
    for (var photo in photos) {
      if (isEdition) {
        // En edición, debe tener archivo nuevo o URL existente
        if (photo.file == null && photo.url.isEmpty) {
          return false;
        }
      } else {
        // En creación, todas deben tener archivo
        if (photo.file == null) {
          return false;
        }
      }
    }
    return true;
  }

  /// Obtiene las fotos que faltan por cargar
  List<String> getMissingPhotos(List<PhotoField> photos, {bool isEdition = false}) {
    final missing = <String>[];
    for (var photo in photos) {
      if (isEdition) {
        if (photo.file == null && photo.url.isEmpty) {
          missing.add(photo.label);
        }
      } else {
        if (photo.file == null) {
          missing.add(photo.label);
        }
      }
    }
    return missing;
  }
}

/// Resultado de operaciones de subida de fotos
class PhotoUploadResult {
  final Map<String, String?> urls;
  final bool hasErrors;
  final List<String> errors;

  PhotoUploadResult({
    required this.urls,
    required this.hasErrors,
    required this.errors,
  });

  bool get isSuccess => !hasErrors && urls.isNotEmpty;
}
