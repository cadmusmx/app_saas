import 'package:intl/intl.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/helpers/regexp_helper.dart';

/// Cambia el formato (format) de una fecha (value), retorna 'no valida' en caso de error
String getFormattedDateStr(String? value, String format) {
  if (value == null) return '';
  try {
    return DateFormat(format).format(DateTime.parse(value));
  } catch (e) {
    return 'no valida';
  }
}

/// Cambia el formato (format) de una fecha (value), retorna null en caso de error
String? getFormattedDateOrNull(String? value, String format) {
  try {
    return value != null ? getFormattedDateStr(value, format) : null;
  } catch (e) {
    DebugLog.error('Error formateando fecha: $e');
    return null;
  }
}

/// retorna la fecha (value) en el formato (format) indicado
String getFormattedDate(DateTime value, String format) {
  try {
    return DateFormat(format).format(value);
  } catch (e) {
    DebugLog.error('Error formateando fecha: $e');
    return 'no valida';
  }
}

/// retorna la fecha actual en el formato (format) indicado
String getCurrentFormattedDate(String format) {
  return DateFormat(format).format(DateTime.now());
}

/// retorna en formato moneda algún valor (value) o cadena vacía si es null
String getFormattedCurrency(dynamic value) {
  if (value == null) return '';
  return '\$$value';
}

/// retorna la fecha correspondiente al valor indicado o null en caso de error
DateTime? parseDateIso(dynamic value) {
  if (value == null || (value is String && value.isEmpty)) return null;
  return DateTime.tryParse(value as String);
}

/// retorna la fecha correspondiente al valor indicado o la fecha actual en caso de error
DateTime parseDate(String date) {
  if (date.isEmpty) return DateTime.now();
  return DateTime.tryParse(date) ?? DateTime.now();
}

/// cambia una cadena de texto de formato snakeCase a Titulo
String snakeToTitle(String text) {
  if (text.isEmpty) return text;
  final words = text.split('_');
  final sentence = words.join(' ');
  return sentence[0].toUpperCase() + sentence.substring(1);
}

/// cambia una cadena de texto de formato snakeCase a camelCase
String snakeToCamel(String text) {
  if (text.trim().isEmpty) return text;

  final words = text.split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return text;

  final buffer = StringBuffer(words.first.toLowerCase());
  for (var i = 1; i < words.length; i++) {
    final word = words[i];
    if (word.isEmpty) continue;
    buffer.write(word[0].toUpperCase());
    if (word.length > 1) buffer.write(word.substring(1).toLowerCase());
  }
  return buffer.toString();
}

/// Quita las URLs y deja el texto limpio
String getText(String body) {
  return body
      .replaceAll(urlRegex, '')
      .replaceAll(RegExp(r'[ \t]+'), ' ') // colapsa espacios sobrantes
      .replaceAll(RegExp(r' *\n *'), '\n') // conserva saltos de línea
      .trim();
}

/// Devuelve TODAS las URLs encontradas (puede ser 0, 1 o varias)
List<String> getLinks(String body) {
  return urlRegex.allMatches(body).map((m) => cleanUrl(m.group(0)!)).toList();
}

/// Limpia puntuación final que la regex suele "comerse" (https://x.com.)
String cleanUrl(String url) {
  return url.replaceAll(RegExp(r'[.,;:!?)\]}>]+$'), '');
}
