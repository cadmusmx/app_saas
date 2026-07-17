import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' show DefaultCacheManager;
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';

// Imágenes

Future<void> showImagesDialog(BuildContext context,
    {required List<VisualTitle<String>> images, bool isQR = false, double? padding}) {
  Container getImage(String src) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: isQR ? const EdgeInsets.all(16.0) : EdgeInsets.all(0),
        child: Image.network(
          src,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image, size: 36)),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  return _showGenericDialog<String>(
    context,
    items: images,
    visualBuilder: (item) => SizedBox(
      width: double.infinity,
      child: InteractiveViewer(
        child: padding != null
            ? Padding(padding: EdgeInsets.all(padding), child: getImage(item.source))
            : getImage(item.source),
      ),
    ),
  );
}

// firmas (Uint8List)

Future<void> showSignaturesDialog(BuildContext context, {required List<VisualTitle<Uint8List>> signatures}) {
  return _showGenericDialog<Uint8List>(
    context,
    items: signatures,
    visualBuilder: (item) => SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Image.memory(item.source, fit: BoxFit.contain),
      ),
    ),
  );
}

// Documentos

final _pdfCacheFutures = <String, Future<File>>{};

Future<File> _getCachedPdf(String url) {
  return _pdfCacheFutures.putIfAbsent(url, () => DefaultCacheManager().getSingleFile(url));
}

Future<void> showDocumentsDialog(
  BuildContext context, {
  required List<VisualTitle<String>> documents,
  int startFrom = 0,
}) {
  return _showGenericDialog<String>(
    context,
    items: documents,
    startFrom: startFrom,
    visualBuilder: (item) => SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.6,
      child: FutureBuilder<File>(
        future: _getCachedPdf(item.source),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text('Error al cargar PDF - ${snapshot.error}', style: Theme.of(context).textTheme.bodyLarge),
              ),
            );
          }
          return PDF().fromPath(snapshot.data!.path, key: ValueKey(item.title));
        },
      ),
    ),
  );
}

Future<void> _showGenericDialog<T>(BuildContext context,
    {required List<VisualTitle<T>> items,
    required Widget Function(VisualTitle<T> item) visualBuilder,
    int startFrom = 0}) async {
  if (items.isEmpty) return Future.value();
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      int currentIndex = (startFrom > items.length || startFrom < 0) ? 0 : startFrom;
      return StatefulBuilder(
        builder: (context, setState) {
          final VisualTitle<T> item = items[currentIndex];
          return AlertDialog(
            contentPadding: EdgeInsets.only(left: 0, right: 0, bottom: items.length > 1 ? 12 : 24),
            constraints: BoxConstraints(minWidth: double.infinity),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(item.title, overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
            content: visualBuilder(item),
            actions: items.length > 1
                ? [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Anterior',
                      color: currentIndex == 0 ? Colors.grey : null,
                      onPressed: currentIndex == 0 ? null : () => setState(() => currentIndex--),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: 'Siguiente',
                      color: currentIndex == items.length - 1 ? Colors.grey : null,
                      onPressed: currentIndex == items.length - 1 ? null : () => setState(() => currentIndex++),
                    ),
                  ]
                : null,
          );
        },
      );
    },
  );
}

/// Crea una lista de VisualTitle&lt;String&gt; a partir de un Map
List<VisualTitle<String>> imagesFromMap(Map<String, dynamic>? photos) {
  if (photos == null) return [];
  return photos.entries.map((photo) => VisualTitle<String>(snakeToTitle(photo.key), '${Config.s3Url}${photo.value}')).toList();
}

/// Crea un Image dentro de un padding a partir de bytes
Widget imageFromBytes(Uint8List bytes, [double padding = 16]) {
  return Container(
    color: Colors.white,
    child: Padding(
      padding: EdgeInsets.all(padding),
      child: Image.memory(bytes, fit: BoxFit.contain, width: double.infinity),
    ),
  );
}

class VisualTitle<T> {
  final String title;
  final T source;
  const VisualTitle(this.title, this.source);
}
