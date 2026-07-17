import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/selection/option_sl.dart';

// Re-exporta OptionSL y OptionSLExtension para que los archivos que hoy
// importan `selection_list.dart` sigan encontrando el modelo sin cambios.
// Una vez migrados todos los consumers a importar `option_sl.dart`
// directamente, este export puede eliminarse.
export 'package:gaso_tenant_app/core/selection/option_sl.dart';

abstract class SelectionList {
  List<OptionSL> get list;
}

abstract class CachedSelectionList implements SelectionList {
  late SharedPreferences _preferences;
  List<OptionSL> _list = [];
  String get spKey;
  Future<ServiceResponse<List<OptionSL>>> fetchFromService();

  CachedSelectionList() {
    SharedPreferences.getInstance().then((preferences) {
      _preferences = preferences;
      List<String>? spList = _preferences.getStringList(spKey);
      if (spList == null) {
        // Cargar desde el servicio
        fetchFromService().then((response) {
          if (response.success && response.data != null) {
            _list = response.data!;
            _cacheList(response.data!);
          } else {
            DebugLog.warning(response.message);
          }
        });
      } else {
        // Cargar desde caché
        _list = _deserializeList(spList);
      }
    });
  }

  @override
  List<OptionSL> get list => _list;

  void _cacheList(List<OptionSL> data) {
    List<String> serialized = data.map((e) => jsonEncode(e.toJson())).toList();
    _preferences.setStringList(spKey, serialized);
  }

  List<OptionSL> _deserializeList(List<String> spList) {
    return spList.map((e) => jsonDecode(e)).map((j) => OptionSL.fromJson(j)).toList();
  }
}
