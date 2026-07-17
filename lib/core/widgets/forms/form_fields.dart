import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/validators/form_validators.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';

abstract class LabelFieldBase extends StatelessWidget {
  final bool edit;
  final String? text;
  final TextEditingController? controller;
  final String helperText;
  final bool capitalization;
  final IconData? icon;
  final String? label;
  final List<TextInputFormatter>? formatters;

  const LabelFieldBase(this.edit, this.text, this.controller, this.helperText,
      {super.key, this.icon, this.label, this.formatters, this.capitalization = false});

  String? Function(String?)? get validator => null;
  List<TextInputFormatter>? get inputFormatters => formatters;
  TextInputType? get keyboardType => TextInputType.text;
  String get displayText => (text != null && text!.isNotEmpty) ? text! : 'Sin registro';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (edit) {
      return TextFormField(
        controller: controller,
        validator: validator,
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
        autocorrect: false,
        textCapitalization: capitalization ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(helperText: helperText, icon: icon != null ? Icon(icon) : null),
      );
    }

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (icon != null) Padding(padding: const EdgeInsets.all(4.0), child: Icon(icon, size: 20)),
        if (label != null)
          Text('$label: ', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(displayText,
            softWrap: true, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.outline)),
      ],
    );
  }
}

class LabelTextField extends LabelFieldBase {
  final String? Function(String?)? customValidator;

  const LabelTextField(
    super.edit,
    super.text,
    super.controller,
    super.helperText, {
    super.key,
    this.customValidator,
    super.icon,
    super.label,
    super.formatters,
    super.capitalization,
  });

  @override
  String? Function(String?)? get validator => customValidator;
}

class LabelDateField extends LabelFieldBase {
  final bool requiredField;

  const LabelDateField(
    super.edit,
    super.text,
    super.controller,
    super.helperText,
    this.requiredField, {
    super.key,
    super.icon,
    super.label,
  });

  @override
  TextInputType? get keyboardType => TextInputType.number;

  @override
  List<TextInputFormatter>? get inputFormatters => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
        _DateFormatter(),
      ];

  @override
  String? Function(String?)? get validator {
    return (value) {
      return FormValidators.valueRegex(
        value,
        requiredField,
        RegExp(r'^(0[1-9]|[12][0-9]|3[01])/(0[1-9]|1[0-2])/([0-9]{4})$'),
        label,
        '(dd/mm/yyyy)',
      );
    };
  }

  @override
  String get displayText {
    if (text == null || text!.isEmpty) return 'Sin registro';
    try {
      return getFormattedDateStr(text, 'dd/MM/yyyy');
    } catch (e) {
      DebugLog.error('Error formateando fecha: $e');
      return 'Formato inválido';
    }
  }
}

class LabelNumberField extends LabelFieldBase {
  final int minLength;
  final int maxLength;
  final bool requiredField;

  const LabelNumberField(
    super.edit,
    super.text,
    super.controller,
    super.helperText,
    this.minLength,
    this.maxLength,
    this.requiredField, {
    super.key,
    super.icon,
    super.label,
  });

  @override
  TextInputType? get keyboardType => TextInputType.number;

  @override
  List<TextInputFormatter>? get inputFormatters =>
      [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxLength)];

  @override
  String? Function(String?)? get validator {
    return (value) {
      final empty = value == null || value.isEmpty;
      if (requiredField && empty) {
        return 'El campo ${label != null ? '$label ' : ''}es requerido';
      }
      if (!requiredField && empty) return null;
      if (!empty && (value.length < minLength || value.length > maxLength)) return _lengthValidMsg;
      return null;
    };
  }

  String get _lengthValidMsg {
    if (minLength == maxLength) {
      return 'Deben ser $minLength dígitos';
    } else {
      return 'Deben ser mínimo $minLength dígitos y máximo $maxLength';
    }
  }
}

class LabelEmailField extends LabelFieldBase {
  final bool requiredField;

  const LabelEmailField(
    super.edit,
    super.text,
    super.controller,
    super.helperText,
    this.requiredField, {
    super.key,
    super.icon,
    super.label,
  });

  @override
  TextInputType? get keyboardType => TextInputType.emailAddress;

  @override
  String? Function(String?)? get validator {
    return (value) => FormValidators.valueRegex(
        value, requiredField, RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'), label, '(correo@email.com)');
  }
}

// Formatters
class _DateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    text = text.replaceAll("/", "");
    var newText = "";
    for (int i = 0; i < text.length; i++) {
      newText += text[i];
      if (i == 1 || i == 3) newText += "/";
    }
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String text;
  final IconData? icon;
  final String? label;
  final Color? labelColor;
  final void Function()? onAction;
  final IconData? actionIcon;

  const InfoRow(
    this.text, {
    this.icon,
    this.label,
    this.labelColor,
    this.onAction,
    this.actionIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (icon != null) Padding(padding: const EdgeInsets.all(4.0), child: Icon(icon, size: 20)),
              if (label != null)
                Text(
                  '$label: ',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: labelColor ?? colorScheme.onSurface,
                  ),
                ),
              Text(
                text.isNotEmpty ? text : 'Sin registro',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: label == null ? FontWeight.bold : null,
                  color: label != null ? colorScheme.outline : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (onAction != null)
          SizedBox(
            height: 32,
            width: 32,
            child: IconButton(
              icon: Icon(actionIcon ?? Icons.edit, size: 20),
              onPressed: onAction,
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

class InfoActionsRow extends StatelessWidget {
  final String text;
  final IconData? icon;
  final String? label;
  final Color? labelColor;
  final void Function() onActionOne;
  final IconData actionIconOne;
  final void Function() onActionTwo;
  final IconData actionIconTwo;

  const InfoActionsRow(
    this.text, {
    required this.onActionOne,
    required this.actionIconOne,
    required this.onActionTwo,
    required this.actionIconTwo,
    this.icon,
    this.label,
    this.labelColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (icon != null) Padding(padding: const EdgeInsets.all(4.0), child: Icon(icon, size: 20)),
              if (label != null)
                Text(
                  '$label: ',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: labelColor ?? colorScheme.onSurface,
                  ),
                ),
              Text(
                text.isNotEmpty ? text : 'Sin registro',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: label == null ? FontWeight.bold : null,
                  color: label != null ? colorScheme.outline : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 32,
          width: 32,
          child: IconButton(
            icon: Icon(actionIconOne, size: 20),
            onPressed: onActionOne,
            padding: EdgeInsets.zero,
          ),
        ),
        SizedBox(
          height: 32,
          width: 32,
          child: IconButton(
            icon: Icon(actionIconTwo, size: 20),
            onPressed: onActionTwo,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

InputDecoration inputDec(String? label, {String? hint, Widget? suffix, FloatingLabelBehavior? flb}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
    suffixIcon: suffix,
    floatingLabelBehavior: flb,
  );
}
