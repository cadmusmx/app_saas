import 'package:flutter/material.dart';

/// Servicio para seleccionar fechas y horas
class DatePickerService {
  static Future<DateTime?> pickFecha(
    BuildContext context, {
    DateTime? currentValue,
    bool includeTime = false,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: currentValue ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2100),
      confirmText: 'Aceptar',
    );

    if (d == null || !context.mounted) return null;

    DateTime result = d;

    if (includeTime) {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentValue ?? DateTime.now()),
        confirmText: 'Aceptar',
      );
      if (t == null) return null;
      result = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }

    return result;
  }

  /// Selecciona solo una fecha (sin hora)
  static Future<DateTime?> pickFechaSola(
    BuildContext context, {
    DateTime? currentValue,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return pickFecha(
      context,
      currentValue: currentValue,
      includeTime: false,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  /// Selecciona fecha y hora
  static Future<DateTime?> pickFechaHora(
    BuildContext context, {
    DateTime? currentValue,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return pickFecha(
      context,
      currentValue: currentValue,
      includeTime: true,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
}
