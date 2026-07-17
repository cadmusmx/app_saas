import 'package:flutter/material.dart';

/// Widget selector de opciones
class OptionSelector<T> extends StatefulWidget {
  final String title;

  /// Opciones como Map (label -> valor)
  final Map<String, T>? optionsMap;

  /// Opciones como List (usa toString() para labels)
  final List<T>? optionsList;

  /// ValueNotifier para controlar el valor seleccionado
  final ValueNotifier<T> valueNotifier;

  /// Valor para "limpiar"
  final T clearValue;
  final double spacing;

  /// Función personalizada para obtener el label de un valor
  final String Function(T)? labelBuilder;

  const OptionSelector({
    super.key,
    required this.title,
    required this.valueNotifier,
    required this.clearValue,
    this.optionsMap,
    this.optionsList,
    this.spacing = 8.0,
    this.labelBuilder,
  }) : assert(optionsMap != null || optionsList != null, 'Debe proporcionar optionsMap o optionsList');

  @override
  State<OptionSelector<T>> createState() => _OptionSelectorState<T>();
}

class _OptionSelectorState<T> extends State<OptionSelector<T>> {
  /// Obtiene las opciones del Map o List
  Map<String, T> get _options {
    if (widget.optionsMap != null) return widget.optionsMap!;
    if (widget.optionsList != null) {
      return {
        for (var item in widget.optionsList!)
          widget.labelBuilder != null ? widget.labelBuilder!(item) : item.toString(): item
      };
    }
    return {};
  }

  void _onOptionSelected(T value) {
    // Si se selecciona el valor actual, limpiar
    if (widget.valueNotifier.value == value) {
      widget.valueNotifier.value = widget.clearValue;
    } else {
      widget.valueNotifier.value = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (widget.title.isNotEmpty) Text(widget.title, style: textTheme.titleMedium),
        ValueListenableBuilder<T>(
          valueListenable: widget.valueNotifier,
          builder: (context, value, child) {
            return Wrap(
              spacing: widget.spacing,
              runSpacing: widget.spacing,
              children: _options.entries.map((entry) {
                final bool isSelected = value == entry.value;
                return isSelected
                    ? FilledButton.tonal(
                        onPressed: () => _onOptionSelected(entry.value),
                        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: Text(entry.key, style: textTheme.labelSmall),
                      )
                    : TextButton(
                        onPressed: () => _onOptionSelected(entry.value),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: Text(entry.key, style: textTheme.labelSmall),
                      );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
