import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoPicker {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickPhoto(BuildContext context,
      {Future<void> Function()? onManage, bool hasImage = false, bool cameraOnly = false}) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Capturar con cámara'),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
                if (!cameraOnly)
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Elegir de galería'),
                    onTap: () => Navigator.pop(ctx, 'gallery'),
                  ),
                if (hasImage && onManage != null)
                  ListTile(
                    leading: const Icon(Icons.visibility),
                    title: const Text('Ver / Limpiar'),
                    onTap: () => Navigator.pop(ctx, 'manage'),
                  ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(ctx, 'cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || choice == 'cancel') return null;

    if (choice == 'manage' && onManage != null) {
      await onManage();
      return null;
    }

    return await _picker.pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2560,
      maxHeight: 2560,
      imageQuality: 85,
    );
  }
}
