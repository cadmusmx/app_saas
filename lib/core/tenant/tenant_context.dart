import 'package:flutter/foundation.dart';
import 'package:gaso_tenant_app/core/tenant/tenant.dart';

class TenantContext extends ChangeNotifier {
  TenantContext._internal();
  static final TenantContext _instance = TenantContext._internal();
  factory TenantContext() => _instance;
  static TenantContext get instance => _instance;

  Tenant? _current;
  Tenant? get current => _current;

  /// Mantiene el getter slug para que HttpService lo inyecte
  /// como header x-tenant-slug sin ningún cambio.
  String? get slug => _current?.slug;
  bool get hasTenant => _current != null;

  void setTenant(Tenant tenant) {
    _current = tenant;
    notifyListeners();
  }

  void clearTenant() {
    _current = null;
    notifyListeners();
  }
}
