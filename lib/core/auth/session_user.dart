import 'package:gaso_tenant_app/core/auth/perm_mask.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/tenant/tenant.dart';

// Los permisos viven en `views[code].mask` como bitmask CRUD (ver `perm_mask.dart`).
// Al mapear cada view se aplica SANEO FAIL-CLOSED:
//   toda máscara no-canónica se fuerza a `Perm.none` (toda no-canónica carece de R,
//   así que forzar a 0 nunca recorta una capacidad legítima) y se deja un tripwire en el log.

/// Usuario autenticado. `admin` se conserva por fidelidad al contrato pero **NO** participa en el RBAC del menú/guards (decisión cerrada).
class AppUser {
  final int? id;
  final String name;
  final String email;
  final bool admin;
  final int? area;
  final int? cityBase;
  final int? department;
  final int? position;
  final int? region;
  final int? company;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.admin,
    this.area,
    this.cityBase,
    this.department,
    this.position,
    this.region,
    this.company,
  });

  factory AppUser.fromMe(Map<String, dynamic> j) => AppUser(
    id: _asInt(j['id']),
    name: (j['name'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    admin: _asBool(j['admin']),
    area: _asInt(j['area']),
    cityBase: _asInt(j['cityBase']),
    department: _asInt(j['departament']),
    position: _asInt(j['position']),
    region: _asInt(j['region']),
    company: _asInt(j['company']),
  );
}

/// "Rol" del usuario dentro del tenant (singular).
class Profile {
  final int? id;
  final String name;
  const Profile({required this.id, required this.name});

  factory Profile.fromMe(Map<String, dynamic> j) => Profile(id: _asInt(j['id']), name: (j['name'] as String?) ?? '');
}

/// Acceso a una vista: máscara CRUD (ya saneada) + metadatos de menú.
class ViewAccess {
  final int mask;
  final String label;
  final String menuGroup;
  const ViewAccess({required this.mask, required this.label, required this.menuGroup});
}

/// Branding del tenant (settings.branding). `primaryColor` es un hex `#RRGGBB`;
/// la conversión a `Color` vive en la capa de UI (app.dart), no en el modelo.
class Branding {
  final String? displayName;
  final String? logoUrl;
  final String primaryColor;

  static const String defaultPrimaryColor = '#7367F0';

  const Branding({this.displayName, this.logoUrl, this.primaryColor = defaultPrimaryColor});

  factory Branding.fromMe(Map<String, dynamic>? j) => Branding(
    displayName: j?['displayName'] as String?,
    logoUrl: j?['logoUrl'] as String?,
    primaryColor: (j?['primaryColor'] as String?) ?? defaultPrimaryColor,
  );
}

/// Sesión completa: usuario + tenant + perfil + accesos + gates del tenant/plan.
class SessionUser {
  final AppUser user;
  final Tenant tenant;
  final Profile profile;
  final Map<String, ViewAccess> views;
  final Map<String, bool> menuGroups; // settings del tenant
  final List<String> planMenuGroups; // límite del plan
  final Branding branding;

  const SessionUser({
    required this.user,
    required this.tenant,
    required this.profile,
    required this.views,
    required this.menuGroups,
    required this.planMenuGroups,
    required this.branding,
  });

  /// Mapea la respuesta cruda de `/api/me`. Punto único donde se sanean las
  /// máscaras (fail-closed) y se emite el tripwire de no-canonicidad.
  factory SessionUser.fromMe(Map<String, dynamic> json) {
    final settings = (json['settings'] as Map?)?.cast<String, dynamic>();
    final branding = (settings?['branding'] as Map?)?.cast<String, dynamic>();

    return SessionUser(
      user: AppUser.fromMe(((json['user'] as Map?) ?? const {}).cast<String, dynamic>()),
      tenant: _tenantFromMe(((json['tenant'] as Map?) ?? const {}).cast<String, dynamic>()),
      profile: Profile.fromMe(((json['profile'] as Map?) ?? const {}).cast<String, dynamic>()),
      views: _viewsFromMe(json['views']),
      menuGroups: _boolMap(json['menuGroups']),
      planMenuGroups: _stringList(json['planMenuGroups']),
      branding: Branding.fromMe(branding),
    );
  }
}

// Mapeo interno

/// El tenant de `/api/me` viene en camelCase (`{id,slug,name,isActive,plan}`),
/// distinto del PascalCase de resolve-tenant (`Tenant.fromBff`). Se construye
/// aquí reusando el modelo de S2, con la misma tolerancia de `isActive`.
Tenant _tenantFromMe(Map<String, dynamic> j) => Tenant(
  id: (j['id'] as String?) ?? '',
  slug: (j['slug'] as String?) ?? '',
  name: (j['name'] as String?) ?? '',
  status: _asBool(j['isActive']) ? 'active' : 'inactive',
);

Map<String, ViewAccess> _viewsFromMe(dynamic raw) {
  final out = <String, ViewAccess>{};
  if (raw is! Map) return out;
  raw.forEach((key, value) {
    if (value is! Map) return;
    final code = key.toString();
    final rawMask = _asInt(value['mask']) ?? Perm.none;

    // SANEO FAIL-CLOSED: no-canónica ⇒ Perm.none. Tripwire para cazar un bug
    // de BFF si alguna vez emitiera una máscara con W/U/D pero sin R.
    final safe = Perm.isCanonical(rawMask) ? rawMask : Perm.none;
    if (safe != rawMask) {
      DebugLog.warning('view $code mask no-canónica: ${Perm.describe(rawMask)} ($rawMask) → -');
    }

    out[code] = ViewAccess(
      mask: safe,
      label: (value['label'] as String?) ?? code,
      menuGroup: (value['menuGroup'] as String?) ?? '',
    );
  });
  return out;
}

Map<String, bool> _boolMap(dynamic raw) {
  final out = <String, bool>{};
  if (raw is! Map) return out;
  raw.forEach((key, value) => out[key.toString()] = _asBool(value));
  return out;
}

List<String> _stringList(dynamic raw) =>
    raw is List ? raw.map((e) => e.toString()).toList(growable: false) : const <String>[];

// Coerciones tolerantes (el BFF/SQL pueden serializar de varias formas)

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Acepta true / 1 / '1' / 'true' como verdadero.
bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v == 1;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true';
  }
  return false;
}
