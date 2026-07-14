/// Modelo de tenant resuelto contra el BFF.
/// El mapeo vive aquí (un solo lugar) para evitar el "drift"
/// entre la forma PascalCase que devuelve el BFF, el almacenamiento local y la UI.
class Tenant {
  final String id;
  final String slug;
  final String name;
  final String status; // 'active' | 'inactive'
  final String? brandingColor;

  const Tenant({required this.id, required this.slug, required this.name, required this.status, this.brandingColor});

  bool get isActive => status == 'active';

  /// Construye un Tenant desde la respuesta del BFF (resolve-tenant):
  /// `{ TenantID, CompanyName, isActive, Dominio }`.
  ///
  /// `isActive` se interpreta de forma tolerante porque distintas capas del
  /// backend lo serializan como bool (`true`) o como int de SQL (`1`).
  factory Tenant.fromBff(Map<String, dynamic> json, {String? fallbackSlug}) {
    return Tenant(
      id: json['TenantID'] as String,
      slug: (json['Dominio'] as String?) ?? fallbackSlug ?? '',
      name: (json['CompanyName'] as String?) ?? fallbackSlug ?? '',
      status: _isActiveFlag(json['isActive']) ? 'active' : 'inactive',
    );
  }

  /// Acepta true / 1 / '1' / 'true' como activo.
  static bool _isActiveFlag(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw == 1;
    if (raw is String) {
      final v = raw.trim().toLowerCase();
      return v == '1' || v == 'true';
    }
    return false;
  }
}
