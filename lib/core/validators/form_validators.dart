class FormValidators {
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingrese $fieldName';
    }
    return null;
  }

  static String? requiredDropdown(String? value, String fieldName) {
    if (value == null || value == '0' || value.isEmpty) {
      return 'Debe seleccionar $fieldName';
    }
    return null;
  }

  /// Permite validar si una cadena de texto es un numero valido
  static String? onlyNumbers(String? value, String label) {
    if (value == null || value.isEmpty) {
      return 'Ingresa $label';
    }
    num? n = num.tryParse(value);
    if (n == null) {
      return 'Ingresa un número válido';
    }
    return null;
  }

  static String? number(String? value, String fieldName, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Ingrese $fieldName' : null;
    }
    if (double.tryParse(value) == null) {
      return 'Debe ser un número válido';
    }
    return null;
  }

  static String? integer(String? value, String fieldName, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Ingrese $fieldName' : null;
    }
    if (int.tryParse(value) == null) {
      return 'Debe ser un número entero';
    }
    return null;
  }

  static String? minValue(String? value, double min) {
    if (value == null || value.isEmpty) return null;
    final number = double.tryParse(value);
    if (number == null) return 'Valor inválido';
    if (number < min) {
      return 'Debe ser al menos $min';
    }
    return null;
  }

  static String? maxValue(String? value, double max) {
    if (value == null || value.isEmpty) return null;
    final number = double.tryParse(value);
    if (number == null) return 'Valor inválido';
    if (number > max) {
      return 'Debe ser menor a $max';
    }
    return null;
  }

  static String? range(String? value, double min, double max) {
    if (value == null || value.isEmpty) return null;
    final number = double.tryParse(value);
    if (number == null) return 'Valor inválido';
    if (number < min || number > max) {
      return 'Debe estar entre $min y $max';
    }
    return null;
  }

  static String? minLength(String? value, int min) {
    if (value == null || value.isEmpty) return null;
    if (value.length < min) {
      return 'Debe tener al menos $min caracteres';
    }
    return null;
  }

  static String? maxLength(String? value, int max) {
    if (value == null || value.isEmpty) return null;
    if (value.length > max) {
      return 'Debe tener máximo $max caracteres';
    }
    return null;
  }

  static String? exactLength(String? value, int length) {
    if (value == null || value.isEmpty) return null;
    if (value.length != length) {
      return 'Debe tener exactamente $length caracteres';
    }
    return null;
  }

  static String? year(String? value, int currentYear, {int yearsBack = 26}) {
    if (value == null || value.isEmpty) return null;
    final year = int.tryParse(value);
    if (year == null) return 'Año inválido';
    final max = currentYear;
    final min = max - yearsBack;
    if (year < min || year > max) {
      return 'Debe estar entre $min y $max';
    }
    return null;
  }

  static String? bankAccount(String? value, String? bankId, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Ingrese $fieldName';
    }
    // Validación específica para BBVA (id = '1')
    if (bankId == '1' && value.length != 10) {
      return 'Para BBVA la cuenta debe tener exactamente 10 dígitos';
    }
    if (value.length < 10) {
      return 'Mínimo 10 dígitos';
    }
    return null;
  }

  static String? confirmField(String? value, String? original, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'La confirmación es requerida';
    }
    if (value != original) {
      return 'Los valores de $fieldName no coinciden';
    }
    return null;
  }

  static String? phone(String? value, String fieldName, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Ingrese $fieldName' : null;
    }
    if (value.length != 10) {
      return '$fieldName debe tener 10 dígitos';
    }
    return null;
  }

  static String? conditional(
    bool condition,
    String? value,
    String fieldName,
  ) {
    if (!condition) return null;
    return required(value, fieldName);
  }

  static String? multipleValidators(
    String? value,
    List<String? Function(String?)> validators,
  ) {
    for (var validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  }

  static String? budgetAmount(String? value, double current, double budget) {
    if (value == null || value.isEmpty) {
      return 'Ingrese el monto';
    }
    final amount = double.tryParse(value);
    if (amount == null) return 'Monto inválido';

    final total = current + amount;
    if (total > budget) {
      return 'El total: \$$total, supera el presupuesto: \$$budget';
    }
    return null;
  }

  static String? valueRegex(String? value, bool requiredField, RegExp regex, [String? label, String? example]) {
    final empty = value == null || value.isEmpty;
    if (requiredField && empty) {
      return 'El campo ${label != null ? '$label ' : ''}es requerido';
    }
    if (!requiredField && empty) return null;
    if (!regex.hasMatch(value!)) {
      return 'Formato no válido ${example ?? ''}';
    }
    return null;
  }
}
