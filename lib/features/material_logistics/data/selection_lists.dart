import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/material_logistics_service.dart';

class XdocksSL extends CachedSelectionList {
  final MaterialLogisticsService _service = MaterialLogisticsService();
  @override
  String get spKey => MaterialLogisticsSPKeys.xdocksML.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getXdocks();
  }
}

class MaterialTypesSL extends CachedSelectionList {
  final MaterialLogisticsService _service = MaterialLogisticsService();
  @override
  String get spKey => MaterialLogisticsSPKeys.materialTypesML.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getMaterialTypes();
  }
}

class IncidenceTypesSL extends CachedSelectionList {
  final MaterialLogisticsService _service = MaterialLogisticsService();
  @override
  String get spKey => MaterialLogisticsSPKeys.incidenceTypesML.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getIncidenceTypes();
  }
}

class EvidenceTypesSL extends CachedSelectionList {
  final MaterialLogisticsService _service = MaterialLogisticsService();
  @override
  String get spKey => MaterialLogisticsSPKeys.evidenceTypesML.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getEvidenceTypes();
  }
}

class CarriersSL extends CachedSelectionList {
  final MaterialLogisticsService _service = MaterialLogisticsService();
  @override
  String get spKey => MaterialLogisticsSPKeys.carriersML.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getCarriers();
  }
}
