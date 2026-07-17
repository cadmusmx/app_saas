import 'package:flutter/material.dart';

String statusText(int estado) => switch (estado) {
      0 => "Pendiente",
      1 => "Aprobada",
      2 => "Rechazada",
      3 => "Cancelada",
      _ => "Desconocida",
    };

Color statusColor(int estado, ColorScheme scheme) => switch (estado) {
      0 => scheme.primary,
      1 => Colors.green,
      2 => scheme.error,
      3 => scheme.tertiary,
      _ => Colors.grey,
    };

Color statusExpColor(int? estado, ColorScheme scheme) => switch (estado) {
      null => scheme.primary,
      1 => Colors.green,
      2 => scheme.error,
      4 => scheme.tertiary,
      _ => Colors.grey,
    };

String statusExpText(int? estado) => switch (estado) {
      null => "Pendiente",
      1 => "Aceptado",
      2 => "Rechazado",
      3 => "Limbo",
      4 => "Pagado",
      _ => "Desconocido",
    };
