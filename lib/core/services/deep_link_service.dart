import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/tenant/tenant.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

/// Escucha deep links con esquema `gasosaas://` y los convierte en navegación.
///
/// Hosts soportados:
///  - `gasosaas://tenant/{slug}` → LoginScreen con la empresa pre-llenada.
///  - `gasosaas://mv/{folio}` o `gasosaas://mv/{slug}/{folio}` → detalle de
///    validación de material (QR del registro).
///
/// El folio es único **por tenant**, no global: dos empresas pueden tener el
/// mismo folio. Por eso se acepta la forma con `{slug}`, que permite detectar
/// que el QR es de otra empresa en vez de abrir un registro homónimo del tenant
/// activo. La forma corta se resuelve contra el tenant activo.
class DeepLinkService {
  final GlobalKey<NavigatorState> navigatorKey;
  final _appLinks = AppLinks();

  static DeepLinkService? _instance;

  /// Deep link recibido durante el arranque, pendiente de abrir.
  /// Ver [_handleMaterialValidation] y [openPending].
  static ({String? slug, String folio})? _pending;

  DeepLinkService(this.navigatorKey) {
    _instance = this;
  }

  Future<void> init() async {
    _appLinks.uriLinkStream.listen(_handle);

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handle(initialUri));
    }
  }

  /// Abre el deep link que quedó pendiente durante el arranque.
  ///
  /// Lo invoca `LoadScreen` **después** de decidir su destino: en cold-start,
  /// `AuthService` todavía no ha leído el token cuando llega el link, y además
  /// `LoadScreen` termina con un `pushReplacementNamed(home)` que borraría
  /// cualquier ruta empujada antes. Navegar aquí evita ambas carreras.
  static void openPending() {
    final pending = _pending;
    _pending = null;
    if (pending == null) return;
    _instance?._openMaterialValidation(pending.slug, pending.folio);
  }

  void _handle(Uri uri) {
    if (uri.scheme != 'gasosaas') return;
    switch (uri.host) {
      case 'tenant':
        _handleTenant(uri);
        break;
      case 'mv':
        _handleMaterialValidation(uri);
        break;
      default:
        DebugLog.warning('Deep link no reconocido: $uri');
    }
  }

  // Tenant

  void _handleTenant(Uri uri) {
    final slug = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    if (slug == null || slug.isEmpty) return;

    final currentTenant = TenantContext.instance.current;
    final hasOtherSession = AuthService.instance.isAuthenticated && currentTenant != null && currentTenant.slug != slug;

    if (hasOtherSession) {
      _showSwitchDialog(slug, currentTenant.slug);
    } else {
      _goToLogin(slug);
    }
  }

  // validación de material

  /// `gasosaas://mv/{folio}` · `gasosaas://mv/{slug}/{folio}`
  void _handleMaterialValidation(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return;

    // Con 2 segmentos el primero es el slug del tenant dueño del registro.
    final String? slug = segments.length >= 2 ? segments.first : null;
    final String folio = segments.length >= 2 ? segments[1] : segments.first;
    if (folio.isEmpty) return;

    // Cold-start: la app sigue arrancando (AuthService aún no leyó el token y
    // LoadScreen no ha decidido destino). Decidir aquí mandaría a login por un
    // falso negativo, y cualquier push sería sustituido por LoadScreen.
    // Se guarda y LoadScreen lo abre vía openPending().
    if (!AuthService.instance.loadedAuthState.value) {
      _pending = (slug: slug, folio: folio);
      return;
    }

    _openMaterialValidation(slug, folio);
  }

  void _openMaterialValidation(String? slug, String folio) {
    final currentTenant = TenantContext.instance.current;
    final isAuthenticated = AuthService.instance.isAuthenticated && AuthService.instance.isTokenValid;

    // Sin sesión: a login. Si el QR trae slug, lo pre-llena.
    if (!isAuthenticated) {
      if (slug != null) {
        _goToLogin(slug);
      } else {
        navigatorKey.currentState?.pushReplacementNamed(AppRoutes.login);
      }
      return;
    }

    // QR de otra empresa: no lo abras contra el tenant activo (el folio podría
    // existir ahí y mostrar un registro distinto).
    if (slug != null && currentTenant != null && currentTenant.slug != slug) {
      _showSwitchDialog(slug, currentTenant.slug);
      return;
    }

    // `RbacGate` de la ruta valida el bit R y la hidratación de sesión.
    navigatorKey.currentState?.pushNamed(AppRoutes.materialValidationDetail, arguments: folio);
  }

  void _showSwitchDialog(String newSlug, String currentSlug) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cambiar empresa'),
        content: Text(
          'Tienes una sesión activa en "$currentSlug".\n'
          '¿Cerrar sesión y entrar a "$newSlug"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await AuthService.instance.logout();
              _goToLogin(newSlug);
            },
            child: const Text('Cambiar empresa'),
          ),
        ],
      ),
    );
  }

  void _goToLogin(String slug) {
    // Slug durable: si LoadScreen gana la carrera y reconstruye el login sin
    // argumentos, initState lo recupera desde TenantContext.
    TenantContext.instance.setTenant(Tenant(id: '', slug: slug, name: slug, status: 'active'));
    navigatorKey.currentState?.pushReplacementNamed(AppRoutes.login, arguments: {'initialSlug': slug});
  }
}
