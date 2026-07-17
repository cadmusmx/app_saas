import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';

class DynamicDropdown extends StatelessWidget {
  final List<OptionSL> list;
  final void Function(OptionSL?) onChanged;
  final FormFieldValidator<OptionSL>? validator;
  final InputDecoration? decoration;
  final OptionSL? initialValue;
  const DynamicDropdown(this.list,
      {required this.onChanged, this.validator, this.decoration, this.initialValue, super.key});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<OptionSL>(
      initialValue: initialValue,
      items: [
        for (var option in list) DropdownMenuItem(value: option, child: Text(option.text)),
      ],
      onChanged: onChanged,
      decoration: decoration,
      validator: validator,
    );
  }
}
