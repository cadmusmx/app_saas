import 'package:flutter/material.dart';

extension MapExtensions on Map<String, dynamic> {
  void renameKey(String oldKey, String newKey) {
    if (containsKey(oldKey)) {
      this[newKey] = remove(oldKey);
    }
  }
}

extension NullExtensions on dynamic {
  String toClearStr() {
    return '${this ?? ''}';
  }

  String? toNullableStr() {
    return this != null ? '$this' : null;
  }
}

extension TimeOfDayFormat on TimeOfDay {
  /// Formato para API / columna SQL TIME: "HH:mm:ss" (segundos siempre 00).
  String toApiTime() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  /// Minutos desde medianoche. Útil para comparar horas sin acarrear fecha.
  int get inMinutes => hour * 60 + minute;
}