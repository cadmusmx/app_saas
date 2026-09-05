import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/core/widgets/media/qr_scan_screen.dart';

/// Quita el esquema/deeplink de un valor de folio: último segmento tras `/`.
/// (`gasosaas://ml/LME-123` → `LME-123`; un folio pelón queda igual.)
String stripFolioScheme(String raw) {
  final s = raw.trim();
  return s.substring(s.lastIndexOf('/') + 1);
}

/// Modal reusable "escanea o ingresa un folio", compartido por las listas de VM y
/// LM (y cualquier flujo que necesite capturar un folio). Devuelve el folio ya
/// **sin deeplink** (vía [stripFolioScheme]) o `null` si se canceló.
///
/// El caller aplica su propia normalización de prefijo (p. ej. VM fuerza `VME-`)
/// y su verificación (`verify-folio` → ramificación). Este helper solo captura.
Future<String?> showFolioEntrySheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String inputLabel = 'Folio',
  String scanTitle = 'Escanear',
}) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle)],
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: inputLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.tag),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, stripFolioScheme(v)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('ESCANEAR'),
                  onPressed: () async {
                    final raw = await Navigator.of(
                      ctx,
                    ).push<String>(MaterialPageRoute(builder: (_) => QrScanScreen(title: scanTitle)));
                    if (raw != null && raw.isNotEmpty) controller.text = stripFolioScheme(raw);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, stripFolioScheme(controller.text)),
                  child: const Text('CONTINUAR'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
