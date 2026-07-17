import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/widgets/forms/photo_upload.dart'; // PhotoField

class DraftManager {
  final String draftKey;

  /// Clave secundaria para el mapa de fotos
  String get _photosKey => '${draftKey}_photos';

  DraftManager(this.draftKey);

  // Directorio exclusivo para este borrador
  Future<Directory> _draftPhotoDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'drafts', draftKey));
  }

  /// Guarda un borrador (solo datos, sin fotos).
  Future<bool> saveDraft(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(draftKey, jsonEncode(data));
      MessengerService.info('Borrador guardado.');
      return true;
    } catch (e) {
      DebugLog.error('Error guardando borrador: $e');
      MessengerService.error('Error al guardar el borrador.');
      return false;
    }
  }

  /// Carga el borrador de datos.
  Future<Map<String, dynamic>?> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = prefs.getString(draftKey);
      if (draft == null) {
        MessengerService.info('No hay borrador guardado.');
        return null;
      }
      MessengerService.info('Borrador cargado.');
      return jsonDecode(draft) as Map<String, dynamic>;
    } catch (e) {
      DebugLog.error('Error cargando borrador: $e');
      MessengerService.error('Error al cargar el borrador.');
      return null;
    }
  }

  /// Elimina el borrador de datos (sin tocar fotos).
  Future<bool> deleteDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(draftKey);
      return true;
    } catch (e) {
      DebugLog.error('Error eliminando borrador: $e');
      return false;
    }
  }

  /// Verifica si existe un borrador
  Future<bool> hasDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(draftKey);
    } catch (e) {
      DebugLog.error('Error verificando borrador: $e');
      return false;
    }
  }

  // FOTOS

  /// Guarda las fotos de [photoGroups] en el directorio del borrador.
  ///
  /// Cada elemento de [photoGroups] corresponde a un grupo (doc, veh, det).
  /// Las imágenes se reciben **ya con marca de agua** (tal como las deja
  /// `PhotoGridMixin`), por lo que solo se copian al directorio persistente.
  ///
  /// Formato del mapa guardado:
  /// ```json
  /// {
  ///   "0": { "frontal": "file:/ruta/absoluta.png" },
  ///   "1": { "lateral_der": "url:imagesRESP/xxx.jpg" }
  /// }
  /// ```
  Future<bool> savePhotos(List<List<PhotoField>> photoGroups) async {
    try {
      final dir = await _draftPhotoDir();

      // Limpia fotos anteriores del borrador
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);

      final Map<String, Map<String, String>> photoMap = {};

      for (int g = 0; g < photoGroups.length; g++) {
        final groupKey = '$g';
        photoMap[groupKey] = {};

        for (final photo in photoGroups[g]) {
          if (photo.file != null) {
            // ── Archivo local: copia al directorio del borrador ──
            final ext = p.extension(photo.file!.path).toLowerCase();
            final dest = p.join(dir.path, '${groupKey}_${photo.key}$ext');
            await File(photo.file!.path).copy(dest);
            photoMap[groupKey]?[photo.key] = 'file:$dest';
          } else if (photo.url.isNotEmpty) {
            // ── URL de S3: solo guarda la cadena ──
            photoMap[groupKey]?[photo.key] = 'url:${photo.url}';
          }
          // Si no hay ni archivo ni URL, no se guarda entrada
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_photosKey, jsonEncode(photoMap));
      return true;
    } catch (e) {
      DebugLog.error('Error guardando fotos del borrador: $e');
      MessengerService.error('Error al guardar las fotos del borrador.');
      return false;
    }
  }

  /// Restaura las fotos guardadas en los grupos de [PhotoField] proporcionados.
  ///
  /// Busca cada foto por `key` dentro del grupo correspondiente y asigna
  /// `file` o `url` según lo que haya sido guardado.
  /// Devuelve `true` si se restauró al menos una foto.
  Future<bool> loadPhotos(List<List<PhotoField>> photoGroups) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_photosKey);
      if (raw == null) return false;
      final photoMap = jsonDecode(raw) as Map<String, dynamic>;
      for (int g = 0; g < photoGroups.length; g++) {
        final groupData = photoMap['$g'] as Map<String, dynamic>?;
        if (groupData == null) continue;
        for (final photo in photoGroups[g]) {
          final entry = groupData[photo.key] as String?;
          if (entry == null) continue;
          if (entry.startsWith('file:')) {
            final path = entry.substring(5);
            final file = File(path);
            if (await file.exists()) {
              photo.file = XFile(path);
              photo.url = '';
            } else {
              // El archivo fue eliminado por el SO; ignora silenciosamente
              DebugLog.warning('Foto del borrador no encontrada: $path');
            }
          } else if (entry.startsWith('url:')) {
            photo.url = entry.substring(4);
            photo.file = null;
          }
        }
      }
      return true;
    } catch (e) {
      DebugLog.error('Error cargando fotos del borrador: $e');
      MessengerService.error('Error al cargar las fotos del borrador.');
      return false;
    }
  }

  /// Elimina los archivos locales **y** la clave de SharedPreferences de las fotos.
  /// Llama a esto al enviar el formulario o al limpiar el borrador.
  Future<bool> deletePhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_photosKey);
      final dir = await _draftPhotoDir();
      if (await dir.exists()) await dir.delete(recursive: true);
      return true;
    } catch (e) {
      DebugLog.error('Error eliminando fotos del borrador: $e');
      return false;
    }
  }

  /// Elimina datos **y** fotos del borrador en una sola llamada.
  Future<void> deleteAll() async {
    await deleteDraft();
    await deletePhotos();
  }
}
