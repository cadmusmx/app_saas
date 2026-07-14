
import 'package:gaso_tenant_app/core/access/access_validator.dart';

class MenuOption {
  String title;
  String image;
  String? description;
  String? path;
  void Function()? onTap;
  bool released;
  MenuOption(this.title, {required this.image, this.description, this.path, this.onTap, this.released = true})
      : assert(path != null || onTap != null, 'Debe proporcionar path o onTap');
}

class MenuOptionAV extends AccessValidator {
  final MenuOption option;
  MenuOptionAV(this.option, {required List<List<String>> config, bool strict = false}) : super(config, strict);
  MenuOptionAV.all(MenuOption option, {bool strict = false}) : this(option, config: AccessConfig.all, strict: strict);
  bool evaluateOption(String department, String profile) {
    return allEmpty() ||
        (strict
            ? (shouldPassByD(department) && shouldPassByP(profile))
            : (shouldPassByD(department) || shouldPassByP(profile)));
  }
}