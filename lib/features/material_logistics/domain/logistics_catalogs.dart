import 'package:gaso_tenant_app/core/selection/option_sl.dart';

/// Catálogos de Logística de Material en un solo holder (reemplaza los 5 GET legacy → `GET /catalogs`).
/// Cada lista se normaliza a `List<OptionSL>` (`value` = clave, `text` = etiqueta).
///
/// Campos por clave (contrato §3.1):
///   xdocks {Id,Nombre} · tiposMaterial {Id,Nombre} · tiposIncidencia {Id,Nombre} ·
///   tiposEvidencia {Id,Nombre} · carriers {Id,Carrier,EsOtro}.
///
/// El carrier "Otro" **no** se identifica por `id == 4`: se resuelve por su flag `EsOtro` del catálogo.
/// Por eso, además de la lista de `OptionSL`, el holder
/// guarda el conjunto de ids con `EsOtro = true` y expone [isCarrierOtro].
class LogisticsCatalogs {
  final List<OptionSL> xdocks;
  final List<OptionSL> materialTypes; // tiposMaterial
  final List<OptionSL> incidenceTypes; // tiposIncidencia
  final List<OptionSL> evidenceTypes; // tiposEvidencia
  final List<OptionSL> carriers;

  /// Ids de carrier con `EsOtro = true` (dinámico; ver contrato §2).
  final Set<int> _otroCarrierIds;

  const LogisticsCatalogs({
    required this.xdocks,
    required this.materialTypes,
    required this.incidenceTypes,
    required this.evidenceTypes,
    required this.carriers,
    required Set<int> otroCarrierIds,
  }) : _otroCarrierIds = otroCarrierIds;

  const LogisticsCatalogs.empty()
      : xdocks = const [],
        materialTypes = const [],
        incidenceTypes = const [],
        evidenceTypes = const [],
        carriers = const [],
        _otroCarrierIds = const {};

  /// True si el carrier (por `value` de `OptionSL`, es decir su `Id` como string)
  /// tiene `EsOtro = true` → obliga a capturar `otroCarrier`.
  bool isCarrierOtro(String? value) {
    if (value == null) return false;
    final id = int.tryParse(value);
    return id != null && _otroCarrierIds.contains(id);
  }

  factory LogisticsCatalogs.fromJson(Map<String, dynamic> json) {
    final carriersRaw = json['carriers'];
    final otros = <int>{};
    if (carriersRaw is List) {
      for (final c in carriersRaw.whereType<Map>()) {
        final esOtro = c['EsOtro'] == true || c['EsOtro'] == 1 || c['EsOtro'] == '1';
        final id = int.tryParse('${c['Id']}');
        if (esOtro && id != null) otros.add(id);
      }
    }
    return LogisticsCatalogs(
      xdocks: _parse(json['xdocks'], valueKey: 'Id', textKey: 'Nombre'),
      materialTypes: _parse(json['tiposMaterial'], valueKey: 'Id', textKey: 'Nombre'),
      incidenceTypes: _parse(json['tiposIncidencia'], valueKey: 'Id', textKey: 'Nombre'),
      evidenceTypes: _parse(json['tiposEvidencia'], valueKey: 'Id', textKey: 'Nombre'),
      carriers: _parse(carriersRaw, valueKey: 'Id', textKey: 'Carrier'),
      otroCarrierIds: otros,
    );
  }

  static List<OptionSL> _parse(dynamic raw, {required String valueKey, required String textKey}) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => OptionSL(value: '${e[valueKey]}', text: '${e[textKey]}')).toList();
  }
}