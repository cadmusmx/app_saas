import 'package:flutter/material.dart';

/// Gestión centralizada de TextEditingControllers
class ControllersManager {
  final Map<String, TextEditingController> _controllers = {};

  /// Obtiene o crea un controlador con un valor inicial
  TextEditingController get(String key, {String initialValue = ''}) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue);
    }
    return _controllers[key]!;
  }

  /// Carga valores desde un Map
  void loadFromMap(Map<String, dynamic> data, {List<String>? keys}) {
    final keysToLoad = keys ?? data.keys.toList();
    for (var key in keysToLoad) {
      if (data.containsKey(key) && _controllers.containsKey(key)) {
        _controllers[key]!.text = data[key]?.toString() ?? '';
      }
    }
  }

  /// Convierte los controladores a un Map
  Map<String, String> toMap({List<String>? keys}) {
    final keysToConvert = keys ?? _controllers.keys.toList();
    return Map.fromEntries(
      keysToConvert
          .where((key) => _controllers.containsKey(key))
          .map((key) => MapEntry(key, _controllers[key]!.text.trim())),
    );
  }

  /// Obtiene el valor de un controlador específico
  String getValue(String key) {
    return _controllers[key]?.text.trim() ?? '';
  }

  /// Establece el valor de un controlador
  void setValue(String key, String value) {
    if (_controllers.containsKey(key)) {
      _controllers[key]!.text = value;
    } else {
      _controllers[key] = TextEditingController(text: value);
    }
  }

  void clear() {
    for (var controller in _controllers.values) {
      controller.clear();
    }
  }

  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  @override
  String toString() {
    return 'ControllersManager(${_controllers.length} controllers)';
  }
}
