import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/tenant/tenant.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

/// Escucha deep links con el esquema `gasosaas://tenant/SLUG`.
/// Navega a LoginScreen pre-llenando el campo empresa.
/// Si ya hay sesión activa con otro tenant, pide confirmación antes de cerrar sesión.
class DeepLinkService {
  final GlobalKey<NavigatorState> navigatorKey;
  final _appLinks = AppLinks();

  DeepLinkService(this.navigatorKey);

  Future<void> init() async {
    _appLinks.uriLinkStream.listen(_handle);

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handle(initialUri));
    }
  }

  void _handle(Uri uri) {
    if (uri.scheme != 'gasosaas' || uri.host != 'tenant') return;
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
