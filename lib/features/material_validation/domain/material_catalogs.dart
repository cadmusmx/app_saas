import 'package:gaso_tenant_app/core/selection/option_sl.dart';

/// Cada catálogo se normaliza a `List<OptionSL>` (`value` = clave, `text` = etiqueta) reusando el item genérico de `core/selection`.
/// Los campos distintos por clave:
///   almacenes {Id,Nombre} · proyectos {Id,Proyecto} · tiposMaterial {Id,Tipo} ·
///   carriers {Id,Carrier} · motivos {Id,Motivo} · estadosFisicos {Clave,Estado} (`estadosFisicos` usa `Clave` char, no `Id`).
class MaterialCatalogs {
  final List<OptionSL> warehouses; // almacenes
  final List<OptionSL> projects; // proyectos
  final List<OptionSL> materialTypes; // tiposMaterial
  final List<OptionSL> carriers; // carriers
  final List<OptionSL> reasons; // motivos
  final List<OptionSL> physicalStatus; // estadosFisicos

  const MaterialCatalogs({
    required this.warehouses,
    required this.projects,
    required this.materialTypes,
    required this.carriers,
    required this.reasons,
    required this.physicalStatus,
  });

  const MaterialCatalogs.empty()
    : warehouses = const [],
      projects = const [],
      materialTypes = const [],
      carriers = const [],
      reasons = const [],
      physicalStatus = const [];

  factory MaterialCatalogs.fromJson(Map<String, dynamic> json) => MaterialCatalogs(
    warehouses: _parse(json['almacenes'], valueKey: 'Id', textKey: 'Nombre'),
    projects: _parse(json['proyectos'], valueKey: 'Id', textKey: 'Proyecto'),
    materialTypes: _parse(json['tiposMaterial'], valueKey: 'Id', textKey: 'Tipo'),
    carriers: _parse(json['carriers'], valueKey: 'Id', textKey: 'Carrier'),
    reasons: _parse(json['motivos'], valueKey: 'Id', textKey: 'Motivo'),
    physicalStatus: _parse(json['estadosFisicos'], valueKey: 'Clave', textKey: 'Estado'),
  );

  static List<OptionSL> _parse(dynamic raw, {required String valueKey, required String textKey}) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => OptionSL(value: '${e[valueKey]}', text: '${e[textKey]}')).toList();
  }
}
