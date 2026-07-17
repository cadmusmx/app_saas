import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';

/// Sección de una carta: un encabezado con cuerpo (párrafo) o viñetas.
class InfoLetterSection {
  final String heading;
  final String? body;
  final List<String>? bullets;

  const InfoLetterSection.text(this.heading, this.body) : bullets = null;
  const InfoLetterSection.bullets(this.heading, this.bullets) : body = null;
}

/// Contenido de una carta informativa de formulario.
/// [summary] es la línea del chip; [title] titula el diálogo.
class InfoLetter {
  final String title;
  final String summary;
  final List<InfoLetterSection> sections;

  const InfoLetter({required this.title, required this.summary, required this.sections});
}

/// Chip informativo para la cabecera de un formulario.
/// Muestra el resumen y, al tocarlo, abre el diálogo con la carta completa.
class InfoLetterChip extends StatelessWidget {
  final InfoLetter letter;
  const InfoLetterChip(this.letter, {super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    return Material(
      color: colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showInfoLetterDialog(context, letter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            spacing: 10,
            children: [
              Icon(Icons.info_outline, size: 20, color: colorScheme.onSecondaryContainer),
              Expanded(
                child: Text(
                  letter.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre la carta completa. Sigue el patrón de `showDetailsDialog`.
Future<void> showInfoLetterDialog(BuildContext context, InfoLetter letter) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final textTheme = TextTheme.of(context);
      return AlertDialog(
        constraints: const BoxConstraints(minWidth: double.infinity),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(letter.title)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final section in letter.sections) ...[
                SectionTitle(section.heading),
                const SizedBox(height: 4),
                if (section.body != null) Text(section.body!, style: textTheme.bodyLarge),
                if (section.bullets != null)
                  for (final item in section.bullets!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          Text('•', style: textTheme.bodyLarge),
                          Expanded(child: Text(item, style: textTheme.bodyLarge)),
                        ],
                      ),
                    ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
        ],
      );
    },
  );
}
