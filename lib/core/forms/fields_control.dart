import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/features/profile/domain/profile.dart';

class FieldValueControl {
  String value; // valor inicial
  String spName; // sirve para identificar en SharedPreferences y en general
  String requestInput; // nombre de la propiedad que recibe la API
  TextEditingController controller;
  FVCType type;

  FieldValueControl(this.value, this.spName, this.controller, this.type, {required this.requestInput});

  bool get changed {
    return type != FVCType.date ? value != controller.text : _getFormattedDate() != controller.text;
  }

  /// Genera el payload con el valor actual del controller
  Map<String, dynamic> get payload {
    return {requestInput: controller.text};
  }

  void setValueToControl() {
    switch (type) {
      case FVCType.date:
        controller.text = _getFormattedDate();
      default:
        controller.text = value;
    }
  }

  void setControlToValue() {
    switch (type) {
      case FVCType.date:
        DateTime date = DateFormat('dd/MM/yyyy').parseUtc(controller.text);
        String iso = date.toIso8601String();
        value = iso;
      default:
        value = controller.text;
    }
  }

  String _getFormattedDate() {
    return type == FVCType.date ? getFormattedDateStr(value, 'dd/MM/yyyy') : 'Invalid';
  }
}

enum FVCType { text, date, number, email }

class EditableField {
  final EUserDataUpdate updateKey;
  final FVCType type;

  EditableField(this.updateKey, {this.type = FVCType.text});
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
