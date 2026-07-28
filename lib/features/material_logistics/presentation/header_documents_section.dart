import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/document_draft.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/material_logistics_holder.dart';

/// Sección "Documentos generales" del arribo (bucket de cabecera).
/// Es **aditivo y opcional** (no sustituye la evidencia por sitio).
///
/// Los documentos viven en el holder (como los sitios); esta sección solo los pinta y edita.
/// El nombre es obligatorio; el archivo acepta jpg/jpeg/png/pdf (máx 5 MB)
/// y no lleva marca de agua (son archivos generales, no evidencia GPS).
class HeaderDocumentsSection extends StatelessWidget {
  const HeaderDocumentsSection({super.key});

  static const int _maxBytes = 5 * 1024 * 1024;
  static const int _maxDocs = 10;

  Future<void> _verArchivo(DocumentDraft d) async {
    final local = d.localPath;
    if (local != null && local.isNotEmpty) {
      await OpenFilex.open(local);
      return;
    }
    if (d.archivo.isEmpty) return MessengerService.info('Archivo no encontrado.');
    try {
      final uri = Uri.parse('${Config.s3Url}${d.archivo}');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        MessengerService.info('No se pudo abrir el archivo.');
      }
    } catch (e) {
      DebugLog.warning('_verArchivo doc $e');
      MessengerService.info('No se pudo abrir el documento.');
    }
  }

  /// Alta (index null) o edición de un documento. Devuelve el draft resultante,
  /// o null si se canceló. `existing` se usa como base en edición.
  Future<DocumentDraft?> _pickDocument(BuildContext context, {DocumentDraft? existing}) async {
    final nameController = TextEditingController(text: existing?.nombre ?? '');
    String? localPath;
    String? mimeType;
    String existingFileName = (existing?.archivo ?? '').isNotEmpty ? existing!.archivo.split('/').last : '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing != null ? 'Editar documento' : 'Agregar documento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                maxLength: 100,
                decoration: inputDec('Nombre del documento', hint: 'Ej. Foto de unidad'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    localPath != null
                        ? localPath!.split('/').last
                        : (existingFileName.isNotEmpty ? existingFileName : 'Seleccionar archivo'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () async {
                    final picked = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                    );
                    if (picked == null || picked.files.single.path == null) return;
                    if (picked.files.single.size > _maxBytes) {
                      return MessengerService.info('El archivo supera el máximo de 5 MB.');
                    }
                    final ext = picked.files.single.extension?.toLowerCase() ?? '';
                    setDlg(() {
                      localPath = picked.files.single.path;
                      mimeType = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
                    });
                  },
                ),
              ),
              if (existing != null && existingFileName.isNotEmpty && localPath == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Archivo actual: $existingFileName', style: Theme.of(ctx).textTheme.bodySmall),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  return MessengerService.info('Escribe el nombre del documento.');
                }
                if (existing == null && localPath == null) {
                  return MessengerService.info('Selecciona un archivo.');
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return null;
    final name = nameController.text.trim();
    if (existing != null) {
      final d = existing.copy()..nombre = name;
      if (localPath != null) {
        d.localPath = localPath;
        d.mimeType = mimeType ?? d.mimeType;
      }
      return d;
    }
    return DocumentDraft(nombre: name, archivo: '', mimeType: mimeType ?? '', localPath: localPath);
  }

  Future<void> _add(BuildContext context, MaterialLogisticsHolder holder) async {
    if (holder.documentos.length >= _maxDocs) {
      return MessengerService.info('Máximo $_maxDocs documentos.');
    }
    final draft = await _pickDocument(context);
    if (draft != null) holder.addDocumento(draft);
  }

  Future<void> _edit(BuildContext context, MaterialLogisticsHolder holder, int index) async {
    final draft = await _pickDocument(context, existing: holder.documentos[index]);
    if (draft != null) holder.updateDocumento(index, draft);
  }

  Widget _docItem(BuildContext context, MaterialLogisticsHolder holder, int index) {
    final d = holder.documentos[index];
    final ref = d.localPath ?? d.archivo;
    final isPdf = d.mimeType.contains('pdf') || ref.toLowerCase().contains('.pdf');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(isPdf ? Icons.picture_as_pdf : Icons.image, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (ref.isNotEmpty)
                  Text(
                    ref.split('/').last,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (ref.isNotEmpty)
            IconButton(tooltip: 'Ver', onPressed: () => _verArchivo(d), icon: const Icon(Icons.visibility)),
          IconButton(onPressed: () => _edit(context, holder, index), icon: const Icon(Icons.edit)),
          IconButton(onPressed: () => holder.removeDocumento(index), icon: const Icon(Icons.delete)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final holder = context.watch<MaterialLogisticsHolder>();
    final docs = holder.documentos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: SectionTitle(
                'Documentos generales',
                subtitle: 'Opcional. Aplican a todo el arribo (imagen o PDF).',
              ),
            ),
            IconButton(
              tooltip: 'Agregar documento',
              icon: const Icon(Icons.add),
              onPressed: () => _add(context, holder),
            ),
          ],
        ),
        if (docs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Sin documentos.', style: Theme.of(context).textTheme.bodySmall),
          )
        else
          for (int i = 0; i < docs.length; i++) _docItem(context, holder, i),
      ],
    );
  }
}
