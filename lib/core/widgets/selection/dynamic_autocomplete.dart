import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';

class DynamicAutocomplete extends StatefulWidget {
  final List<OptionSL> list;
  final void Function(OptionSL) onSelected;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextEditingController? controller;
  final OptionSL? initialValue;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool preview;

  const DynamicAutocomplete(
    this.list, {
    required this.onSelected,
    this.decoration,
    this.validator,
    this.inputFormatters,
    this.controller,
    this.initialValue,
    this.enabled = true,
    this.autovalidateMode,
    this.focusNode,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.preview = false,
    super.key,
  });

  @override
  State<DynamicAutocomplete> createState() => _DynamicAutocompleteState();
}

class _DynamicAutocompleteState extends State<DynamicAutocomplete> {
  late TextEditingController _controller;
  bool _isInternalController = false;
  TextEditingController? _fieldController;
  bool _isUpdatingController = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    if (widget.controller == null) {
      _controller = TextEditingController(
        text: widget.initialValue?.text ?? '',
      );
      _isInternalController = true;
    } else {
      _controller = widget.controller!;
      _isInternalController = false;

      if (widget.initialValue != null && _controller.text.isEmpty) {
        _controller.text = widget.initialValue!.text;
      }
    }

    // Escuchar cambios en el controller externo
    _controller.addListener(_onExternalControllerChanged);
  }

  void _onExternalControllerChanged() {
    // Evitar bucles de actualización
    if (_isUpdatingController) return;

    // Si el controller externo cambia, sincronizar con el field controller
    if (_fieldController != null && _fieldController!.text != _controller.text) {
      // Usar post frame callback para evitar setState durante build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _fieldController != null) {
          _isUpdatingController = true;
          _fieldController!.value = _controller.value;
          _isUpdatingController = false;
        }
      });
    }
  }

  @override
  void didUpdateWidget(DynamicAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambió el controller externo
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onExternalControllerChanged);
      if (_isInternalController) _controller.dispose();
      _initializeController();
    }

    // Actualizar el texto si initialValue cambió
    if (widget.initialValue != oldWidget.initialValue && widget.initialValue != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.text = widget.initialValue!.text;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onExternalControllerChanged);
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<OptionSL>(
      initialValue: TextEditingValue(text: _controller.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return widget.preview ? widget.list.take(10) : const Iterable<OptionSL>.empty();
        }
        return widget.list.where((OptionSL option) {
          return option.text.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (OptionSL selected) {
        _controller.text = selected.text;
        widget.onSelected(selected);
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Guardar referencia al field controller solo una vez
        if (_fieldController != textEditingController) {
          _fieldController = textEditingController;

          // Sincronizar inicialmente
          if (textEditingController.text != _controller.text) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                textEditingController.value = _controller.value;
              }
            });
          }

          // Escuchar cambios del usuario en el campo
          textEditingController.addListener(() {
            if (_isUpdatingController) return;
            if (textEditingController.text != _controller.text) {
              // Actualizar el controller externo cuando el usuario escribe
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_isUpdatingController) {
                  _isUpdatingController = true;
                  _controller.value = textEditingController.value;
                  _isUpdatingController = false;
                }
              });
            }
          });
        }

        return TextFormField(
          decoration: widget.decoration ?? const InputDecoration(),
          validator: widget.validator,
          inputFormatters: widget.inputFormatters,
          enabled: widget.enabled,
          controller: textEditingController,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          focusNode: widget.focusNode ?? focusNode,
          autovalidateMode: widget.autovalidateMode,
          onFieldSubmitted: (String value) {
            onFieldSubmitted();
          },
        );
      },
      displayStringForOption: (OptionSL option) => option.text,
    );
  }
}
