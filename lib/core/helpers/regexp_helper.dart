final curpRegExp = RegExp(
    r'^[A-ZÑ]{4}\d{6}[HM](?:AS|BC|BS|CC|CL|CM|CS|CH|DF|DG|GT|GR|HG|JC|MC|MN|MS|NT|NL|OC|PL|QT|QR|SP|SL|SR|TC|TL|TS|VZ|YN|ZS)[B-DF-HJ-NP-TV-Z]{3}[0-9A-Z]{2}$',
    caseSensitive: false);
final rfcRegExp = RegExp(r'^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$', caseSensitive: false);

/// Solo números
final numberExp = RegExp(r'^[0-9]+$');

/// Solo números con 2 decimales
final decimalExp = RegExp(r'^\d+\.?\d{0,2}');

/// Letras, números y guiones
final lngExp = RegExp(r'^[a-zA-Z0-9\-]+$', unicode: true);

/// Letras, números, guiones y guion bajo
final lngGExp = RegExp(r'^[a-zA-Z0-9\-_]+$', unicode: true);

/// Solo letras (mayúsculas, minúsculas, acentos y espacios)
final namesExp = RegExp(r'^[\p{L}\s]+$', unicode: true);

/// Letras, números, espacios y algunos símbolos básicos
final lneSBExp = RegExp(r'^[\p{L}0-9\s#\-\.,%/@&()]+$', unicode: true);

/// caracteres no usados en general
final notUsedExp = RegExp(r'[`[\]{}=<>|]');

final RegExp urlRegex = RegExp(r'https?://\S+');
