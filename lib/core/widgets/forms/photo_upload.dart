import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gaso_tenant_app/core/widgets/media/photo_picker.dart';
import 'package:gaso_tenant_app/core/services/image_service.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';

// Clase base abstracta para el manejo de fotos
abstract class PhotoData {
  bool get hasImage;
  Widget buildImageWidget();
}

// Implementación para fotos (archivo o URL)
class FileUrlPhotoData implements PhotoData {
  final String url;
  final XFile? file;

  FileUrlPhotoData(this.url, this.file);

  @override
  bool get hasImage => file != null || url.isNotEmpty;

  @override
  Widget buildImageWidget() {
    if (url.isNotEmpty) {
      return Image.network(
        '${Config.s3Url}$url',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image, size: 36)),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );
    } else {
      return Image.file(
        File(file!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image, size: 36)),
      );
    }
  }
}

// Clase base abstracta para el grid de fotos
abstract class BasePhotosGrid extends StatefulWidget {
  final List<PhotoField> fields;
  final BuildContext context;
  final String watermark;
  final bool cameraOnly;

  const BasePhotosGrid(this.context, this.fields, {this.watermark = '', this.cameraOnly = false, super.key});
}

// Mixin para funcionalidad común
mixin PhotoGridMixin<T extends BasePhotosGrid> on State<T> {
  final ImageService _imageService = ImageService();
  final PhotoPicker _photoPicker = PhotoPicker();
  late final messenger = ScaffoldMessenger.of(widget.context);

  PhotoData getPhotoData(int index);
  void updatePhotoData(int index, XFile? file);
  void clearPhotoData(int index);

  Future<void> _onPickPhoto(int index) async {
    try {
      final XFile? picked = await _photoPicker.pickPhoto(
        widget.context,
        onManage: () async {
          await _showPhotoManageDialog(index);
        },
        hasImage: getPhotoData(index).hasImage,
        cameraOnly: widget.cameraOnly,
      );

      if (picked != null) {
        if (widget.watermark.isNotEmpty) {
          final file = await _imageService.waterMarkImage(picked, widget.watermark);
          if (mounted) setState(() => updatePhotoData(index, XFile(file.path)));
        } else {
          if (mounted) setState(() => updatePhotoData(index, picked));
        }
      }
    } on PlatformException catch (e) {
      DebugLog.warning(e.message ?? '$e');
      _snack('No se pudo acceder al recurso');
    } catch (e) {
      DebugLog.warning('Error: $e');
      _snack('Ocurrió un error, intente mas tarde');
    }
  }

  Future<void> _showPhotoManageDialog(int index, [String title = 'Vista previa']) async {
    final photoData = getPhotoData(index);
    if (!photoData.hasImage) return;

    await showDialog(
      context: widget.context,
      fullscreenDialog: true,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: InteractiveViewer(
          child: photoData.buildImageWidget(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              if (mounted) setState(() => clearPhotoData(index));
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final isWide = cons.maxWidth > 640 && cons.maxWidth < 1200;
        final isFullWide = cons.maxWidth > 1200;
        final crossAxisCount = isFullWide
            ? 6
            : isWide
                ? 4
                : 2;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: widget.fields.length,
          itemBuilder: (ctx, i) {
            final field = widget.fields[i];
            final photoData = getPhotoData(i);

            return InkWell(
              onTap: () => _onPickPhoto(i),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: photoData.hasImage
                          ? photoData.buildImageWidget()
                          : const Center(child: Icon(Icons.add_a_photo, size: 36)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child:
                          Text(field.label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: photoData.hasImage
                          ? TextButton.icon(
                              onPressed: () => _showPhotoManageDialog(i, field.label),
                              icon: const Icon(Icons.settings),
                              label: const Text('Opciones'),
                            )
                          : TextButton.icon(
                              onPressed: () => _onPickPhoto(i),
                              icon: const Icon(Icons.upload),
                              label: const Text('Subir'),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PhotosGrid extends BasePhotosGrid {
  const PhotosGrid(
    super.context,
    super.fields, {
    super.watermark,
    super.cameraOnly,
    super.key,
  });

  @override
  State<PhotosGrid> createState() => _PhotosGridState();
}

class _PhotosGridState extends State<PhotosGrid> with PhotoGridMixin<PhotosGrid> {
  @override
  void dispose() {
    for (var i = 0; i < widget.fields.length; i++) {
      clearPhotoData(i);
    }
    super.dispose();
  }

  @override
  PhotoData getPhotoData(int index) {
    final photo = widget.fields[index];
    return FileUrlPhotoData(photo.url, photo.file);
  }

  @override
  void updatePhotoData(int index, XFile? file) {
    widget.fields[index].url = '';
    widget.fields[index].file = file;
  }

  @override
  void clearPhotoData(int index) {
    widget.fields[index].url = '';
    widget.fields[index].file = null;
  }
}

class PhotoField {
  final String key;
  final String label;
  String url;
  XFile? file;
  PhotoField(this.key, this.label, [this.url = '', this.file]);
}
