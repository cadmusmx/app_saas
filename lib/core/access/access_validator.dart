class AccessValidator {
  final List<List<String>> config;
  late final List<String> allowedP;
  late final List<String> allowedD;
  late final List<String> notAllowedP;
  late final List<String> notAllowedD;
  final bool strict;

  AccessValidator(this.config, this.strict) : assert(config.length == 4, 'config debe tener exactamente 4 listas') {
    allowedP = config[0];
    allowedD = config[1];
    notAllowedP = config[2];
    notAllowedD = config[3];
  }

  bool allEmpty() {
    return notAllowedD.isEmpty && notAllowedP.isEmpty && allowedD.isEmpty && allowedP.isEmpty;
  }

  bool shouldPassByP(String idProfile) {
    return (notAllowedP.isEmpty || !notAllowedP.contains(idProfile)) &&
        (allowedP.isEmpty || allowedP.contains(idProfile));
  }

  bool shouldPassByD(String idDepartment) {
    return (notAllowedD.isEmpty || !notAllowedD.contains(idDepartment)) &&
        (allowedD.isEmpty || allowedD.contains(idDepartment));
  }
}

/// configuración general
class AccessConfig {
  static const List<List<String>> all = [[], [], [], []];
  static const List<List<String>> responsiva = [['1'], ['3'], [], []];
}
