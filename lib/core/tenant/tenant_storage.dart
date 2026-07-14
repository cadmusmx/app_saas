import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaso_tenant_app/core/tenant/tenant.dart';

class TenantStorage {
  static const _keyId     = 'tenant_id';
  static const _keyName   = 'tenant_name';
  static const _keySlug   = 'tenant_slug';
  static const _keyStatus = 'tenant_status';

  Future<void> save(Tenant tenant) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyId,     tenant.id);
    await p.setString(_keyName,   tenant.name);
    await p.setString(_keySlug,   tenant.slug);
    await p.setString(_keyStatus, tenant.status);
  }

  Future<Tenant?> load() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_keyId);
    if (id == null) return null;
    return Tenant(
      id:     id,
      name:   p.getString(_keyName)   ?? '',
      slug:   p.getString(_keySlug)   ?? '',
      status: p.getString(_keyStatus) ?? '',
    );
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyId);
    await p.remove(_keyName);
    await p.remove(_keySlug);
    await p.remove(_keyStatus);
  }
}
