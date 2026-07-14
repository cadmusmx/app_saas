import 'package:flutter/foundation.dart';

import 'package:gaso_tenant_app/core/auth/perm_mask.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';

/// Contexto de sesión RBAC del cliente. Es un HOLDER puro: no llama a la red.
/// La hidratación (getMe → set) la orquesta la capa de auth (features/auth), respetando la regla "core no importa features".
///
/// Singleton + ChangeNotifier (mismo patrón que AuthService.instance):
///   - `.instance` para leer permisos desde builders de ruta / guards.
///   - provisto con ChangeNotifierProvider.value para que el drawer/home reaccionen a login / logout / cambio de tenant.
class AuthContext with ChangeNotifier {
  AuthContext._internal();
  static final AuthContext _instance = AuthContext._internal();
  factory AuthContext() => _instance;
  static AuthContext get instance => _instance;

  SessionUser? _current;
  SessionUser? get current => _current;

  bool get hasSession => _current != null;
  Branding? get branding => _current?.branding;

  /// Fija la sesión hidratada (tras login/MFA o restauración en arranque).
  void setSession(SessionUser session) {
    _current = session;
    notifyListeners();
  }

  /// Limpia la sesión (logout / 401 / cambio de empresa). No toca el tenant.
  void clear() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  // Máscara ya saneada (fail-closed) al mapear /api/me, así que canWrite/
  // canUpdate/canDelete son seguras por construcción: sin R no hay W/U/D.

  int maskOf(String viewCode) => _current?.views[viewCode]?.mask ?? Perm.none;

  /// Visibilidad de menú + guard de ruta de LECTURA (bit R).
  bool hasView(String viewCode) => Perm.hasRead(maskOf(viewCode));

  bool canWrite(String viewCode) => Perm.hasWrite(maskOf(viewCode));
  bool canUpdate(String viewCode) => Perm.hasUpdate(maskOf(viewCode));
  bool canDelete(String viewCode) => Perm.hasDelete(maskOf(viewCode));

  /// ¿Puede entrar a una ruta de MUTACIÓN (alta/edición/baja)? Cualquier W/U/D.
  bool canMutate(String viewCode) {
    final m = maskOf(viewCode);
    return Perm.hasWrite(m) || Perm.hasUpdate(m) || Perm.hasDelete(m);
  }

  /// Grupo habilitado = permitido por el plan Y activado en settings del tenant.
  bool isGroupEnabled(String group) =>
      (_current?.planMenuGroups.contains(group) ?? false) && (_current?.menuGroups[group] ?? false);
}