import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';
import 'package:gaso_tenant_app/core/helpers/regexp_helper.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/lists/tiles.dart';

Future<bool?> showTFDialog(BuildContext context, String title, String message, String trueAnswer, String falseAnswer) {
  return showDialog<bool?>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      final textStyle = Theme.of(context).textTheme.bodyLarge;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, null))
              ],
            ),
            content: Text(message, style: textStyle),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(falseAnswer)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(trueAnswer)),
            ],
          );
        },
      );
    },
  );
}

/// ### (respuesta, no preguntar)
Future<(bool, bool)?> showTFDialogAsk(
    BuildContext context, String title, String message, String trueAnswer, String falseAnswer) {
  bool dontAsk = false;
  return showDialog<(bool, bool)>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      final textStyle = Theme.of(context).textTheme.bodyLarge;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, null))
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: textStyle),
                InkWell(
                  onTap: () => setState(() => dontAsk = !dontAsk),
                  child: Row(
                    children: [
                      Checkbox(
                        value: dontAsk,
                        onChanged: (value) => setState(() => dontAsk = value ?? false),
                      ),
                      const Text("No volver a preguntar"),
                    ],
                  ),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, (false, dontAsk)), child: Text(falseAnswer)),
              TextButton(onPressed: () => Navigator.pop(context, (true, dontAsk)), child: Text(trueAnswer)),
            ],
          );
        },
      );
    },
  );
}

Future<bool?> showTFContentDialog(
    BuildContext context, String title, Widget content, String trueAnswer, String falseAnswer) {
  return showDialog<bool?>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, null))
              ],
            ),
            content: content,
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(falseAnswer)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(trueAnswer)),
            ],
          );
        },
      );
    },
  );
}

Future<T?> showOptionsDialog<T>(BuildContext context, String title, String message, Map<String, T> options) {
  return showDialog<T?>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      final textStyle = Theme.of(context).textTheme.bodyLarge;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, null))
              ],
            ),
            content: Text(message, style: textStyle),
            actions: [
              for (var option in options.entries)
                TextButton(onPressed: () => Navigator.pop(context, option.value), child: Text(option.key))
            ],
          );
        },
      );
    },
  );
}

/// Dialog con select (options < valor, etiqueta >) y campo de texto, al confirmar retorna sus valores,
Future<OptionText<String>?> showOptionTextDialog(
    BuildContext context, String title, List<OptionSL> options, String selectLabel, String textLabel,
    {String? option, String text = ''}) {
  OptionText<String> optionText = OptionText(option, text);
  bool isValid = false;
  return showDialog<OptionText<String>>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, null))
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: optionText.option,
                  items: [
                    for (var c in options)
                      DropdownMenuItem(
                        value: c.value,
                        child: Text('${c.value}. ${c.text}', overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    optionText.option = value;
                    isValid = optionText.text.isNotEmpty;
                  }),
                  decoration: inputDec(selectLabel),
                ),
                TextFormField(
                  initialValue: optionText.text,
                  decoration: inputDec(textLabel),
                  minLines: 4,
                  maxLines: 6,
                  onChanged: (value) => setState(() {
                    optionText.text = value;
                    isValid = optionText.option != null && optionText.text.isNotEmpty;
                  }),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(300),
                    FilteringTextInputFormatter.deny(notUsedExp)
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, isValid ? optionText : null),
                child: Text(isValid ? 'Confirmar' : 'Cancelar'),
              ),
            ],
          );
        },
      );
    },
  );
}

class OptionText<T> {
  T? option;
  String text;
  OptionText(this.option, this.text);
}

Future<void> showDetailsDialog(BuildContext context, String title, List<Widget> children) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            constraints: BoxConstraints(minWidth: double.infinity),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> showFilterModal(
  BuildContext context, {
  List<Widget> children = const <Widget>[],
  required void Function() onClean,
  required void Function() onFilter,
}) async {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: children,
                    ),
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(child: TextButton(onPressed: onClean, child: const Text('Limpiar'))),
                      Expanded(child: FilledButton(onPressed: onFilter, child: const Text('Aplicar filtros'))),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> showNavigationDialog(BuildContext context, String title, List<NavDialogOption> navOptions) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            constraints: BoxConstraints(minWidth: double.infinity),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var opt in navOptions)
                    NavigationListTile(opt.title, opt.icon, () {
                      if (opt.path != null) {
                        Navigator.popAndPushNamed(context, opt.path!);
                      } else {
                        MessengerService.info('En proceso');
                      }
                    }),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class NavDialogOption {
  String title;
  IconData icon;
  String? path;
  NavDialogOption(this.title, this.path, this.icon);
}
