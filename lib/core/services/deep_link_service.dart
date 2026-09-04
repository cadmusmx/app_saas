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
///  - `gasosaas://mv/{folio}` → detalle de validación de material (QR del registro).
///  - `gasosaas://ml/{folio}` → detalle de logística de material (QR del registro).
///
/// El folio viaja sin slug: el registro se resuelve siempre contra el tenant activo.
/// El BFF acota por `TenantID`, así que un QR de otra empresa devuelve 404 y nunca expone datos ajenos.
class DeepLinkService with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey;
  final _appLinks = AppLinks();

  /// Último link procesado. Solo lo usa la red de seguridad de `resumed` para
  /// no reabrir el mismo link al volver a primer plano.
  String? _lastHandled;

  static DeepLinkService? _instance;

  /// Folio recibido durante el arranque, pendiente de abrir. Ver [openPending].
  static String? _pendingFolio;

  DeepLinkService(this.navigatorKey) {
    _instance = this;
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    _appLinks.uriLinkStream.listen((uri) {
      DebugLog.info('[deeplink] stream: $uri');
      _handle(uri);
    }, onError: (Object e) => DebugLog.error('[deeplink] stream error: $e'));

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handle(initialUri));
    }
  }

  /// Red de seguridad para la entrega **en caliente**.
  ///
  /// Cuando la app ya está viva, Android entrega el deep link por `onNewIntent` y el plugin debería emitirlo en `uriLinkStream`.
  /// Si esa entrega falla, al volver a primer plano se relee el intent actual.
  /// `_lastHandled` evita reabrir el link que ya se procesó.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri == null) return;
          if (uri.toString() == _lastHandled) return;
          DebugLog.info('[deeplink] resume-fallback: $uri');
          _handle(uri);
        })
        .catchError((Object e) {
          DebugLog.error('[deeplink] resume-fallback error: $e');
        });
  }

  /// Abre el deep link que quedó pendiente durante el arranque.
  ///
  /// Lo invoca `LoadScreen` **después** de decidir su destino: en cold-start,
  /// `AuthService` todavía no ha leído el token cuando llega el link, y además
  /// `LoadScreen` termina con un `pushReplacementNamed(home)` que borraría cualquier ruta empujada antes.
  /// Navegar aquí evita ambas carreras. El módulo se resuelve por el prefijo del folio.
  static void openPending() {
    final folio = _pendingFolio;
    _pendingFolio = null;
    if (folio == null) return;
    if (folio.startsWith('VM')) {
      _instance?._openMaterialValidation(folio);
    } else if (folio.startsWith('LM')) {
      _instance?._openMaterialLogistics(folio);
    }
  }

  void _handle(Uri uri) {
    if (uri.scheme != 'gasosaas') return;
    _lastHandled = uri.toString();
    switch (uri.host) {
      case 'tenant':
        _handleTenant(uri);
        break;
      case 'mv':
        _handleMaterial(uri, _openMaterialValidation);
        break;
      case 'ml':
        _handleMaterial(uri, _openMaterialLogistics);
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

  // Material (validación y logística comparten mecánica; difieren en la ruta destino)

  String? getFolioFromUri(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final folio = segments.first;
    if (folio.isEmpty) return null;
    return folio;
  }

  /// `gasosaas://ml/{folio}` o `gasosaas://mv/{folio}`
  void _handleMaterial(Uri uri, void Function(String) openFn) {
    final folio = getFolioFromUri(uri);
    if (folio == null) return;

    // Cold-start: la app sigue arrancando (AuthService aún no leyó el token y LoadScreen no ha decidido destino).
    // Decidir aquí mandaría a login por un falso negativo, y cualquier push sería sustituido por LoadScreen.
    if (!AuthService.instance.loadedAuthState.value) {
      DebugLog.info('[deeplink] material pendiente (app arrancando): $folio');
      _pendingFolio = folio;
      return;
    }

    openFn(folio);
  }

  bool _authGuard() {
    final isAuthenticated = AuthService.instance.isAuthenticated && AuthService.instance.isTokenValid;
    if (!isAuthenticated) {
      navigatorKey.currentState?.pushReplacementNamed(AppRoutes.login);
      return false;
    }
    return true;
  }

  void _openMaterialValidation(String folio) {
    // `RbacGate` de la ruta valida el bit R y la hidratación de sesión.
    // Si el folio no existe en el tenant activo, el detalle muestra el 404 del BFF.
    if (_authGuard()) navigatorKey.currentState?.pushNamed(AppRoutes.materialValidationDetail, arguments: folio);
  }

  void _openMaterialLogistics(String folio) {
    // `RbacGate` de la ruta valida el bit R y la hidratación de sesión.
    // Si el folio no existe en el tenant activo, el detalle muestra el 404 del BFF.
    if (_authGuard()) navigatorKey.currentState?.pushNamed(AppRoutes.materialLogisticsDetail, arguments: folio);
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
