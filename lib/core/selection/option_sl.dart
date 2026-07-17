/// Modelo genérico de opción (texto + valor) usado por dropdowns, autocompletes
/// y cualquier selector en la app.
///
/// Este archivo contiene únicamente el modelo y no depende de Flutter ni de
/// SharedPreferences. Las abstracciones de listas cacheables
/// (`SelectionList`, `CachedSelectionList`) y sus subclases concretas viven
/// en `selection_list.dart`.
class OptionSL {
  String text;
  String value;

  OptionSL({required this.text, required this.value});

  OptionSL.empty()
      : text = '',
        value = '0';

  Map<String, dynamic> toJson() => {'text': text, 'value': value};

  factory OptionSL.fromJson(Map<String, dynamic> json) => OptionSL(text: json['text'], value: json['value']);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OptionSL && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

extension OptionSLExtension on List<OptionSL> {
  Map<String, String> toVTMap() {
    return {for (var option in this) option.value: option.text};
  }

  Map<String, String> toTVMap() {
    return {for (var option in this) option.text: option.value};
  }

  OptionSL? getByValue(String? value) {
    if (value == null) return null;
    int i = indexWhere((o) => o.value == value);
    if (i >= 0) return this[i];
    return null;
  }
}
