import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/selection/selection_list.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';
import 'package:gaso_tenant_app/features/material_validation/data/material_validation_service.dart';

class WarehousesSL extends CachedSelectionList {
  final MaterialValidationService _service = MaterialValidationService();
  @override
  String get spKey => MaterialValidationSPKeys.warehousesMV.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getWarehouses();
  }
}

class ProjectsSL extends CachedSelectionList {
  final MaterialValidationService _service = MaterialValidationService();
  @override
  String get spKey => MaterialValidationSPKeys.projectsMV.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getProjects();
  }
}

class MaterialTypesSL extends CachedSelectionList {
  final MaterialValidationService _service = MaterialValidationService();
  @override
  String get spKey => MaterialValidationSPKeys.materialTypesMV.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getMaterialTypes();
  }
}

class ReasonsSL extends CachedSelectionList {
  final MaterialValidationService _service = MaterialValidationService();
  @override
  String get spKey => MaterialValidationSPKeys.reasonsVM.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getReasons();
  }
}

class CarriersSL extends CachedSelectionList {
  final MaterialValidationService _service = MaterialValidationService();
  @override
  String get spKey => MaterialValidationSPKeys.carriersVM.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getCarriers();
  }
}

class PhysicalStatusSL extends CachedSelectionList {
  final MaterialValidationService _service = MaterialValidationService();
  @override
  String get spKey => MaterialValidationSPKeys.physicalStatusVM.name;

  @override
  Future<ServiceResponse<List<OptionSL>>> fetchFromService() {
    return _service.getPhysicalStatus();
  }
}
