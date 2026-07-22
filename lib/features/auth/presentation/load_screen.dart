import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/services/deep_link_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_storage.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';
import 'package:gaso_tenant_app/features/auth/presentation/session_retry_screen.dart';

enum _LoadMode { loading, offlineRetry }


/// Pantalla de arranque: restaura tenant + sesión de disco y decide destino.
///   - Sin sesión válida → /home (TenantGate/AuthWrapper mandan a /login).
///   - Sesión válida + RBAC hidratado → /home.
///   - Sesión válida pero RBAC NO hidratado (cold-start offline) → reintento (B).
class LoadScreen extends StatefulWidget {
  const LoadScreen({super.key});

  @override
  State<LoadScreen> createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  _LoadMode _mode = _LoadMode.loading;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    /// 1. Restaurar tenant desde disco a memoria (para pre-llenar el login).
    /// No pisa un slug puesto por el deep link.
    final savedTenant = await TenantStorage().load();
    if (savedTenant != null && TenantContext.instance.current == null) {
      TenantContext.instance.setTenant(savedTenant);
    }

    /// 2. Esperar a que AuthService termine de leer secure storage
    /// (incluye la hidratación best-effort de la sesión RBAC vía hydrateSession).
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.loadedAuthState.value) {
      final completer = Completer<void>();
      void onChanged() {
        if (authService.loadedAuthState.value) {
          authService.loadedAuthState.removeListener(onChanged);
          completer.complete();
        }
      }

      authService.loadedAuthState.addListener(onChanged);
      await completer.future;
    }

    if (!mounted) return;

    /// 3. Decidir destino.
    /// Si hay sesión válida pero la hidratación RBAC no ocurrió (getMe falló, típicamente offline),
    /// mostrar reintento en vez de un home vacío.
    /// En cualquier otro caso, ir a /home y dejar que TenantGate/AuthWrapper decidan (login si no hay sesión).
    final hasValidSession = authService.isAuthenticated && authService.isTokenValid;
    if (hasValidSession && AuthContext.instance.current == null) {
      setState(() => _mode = _LoadMode.offlineRetry);
      return;
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    // Deep link llegado durante el arranque: se abre ENCIMA de /home 
    // (así "atrás" regresa al inicio en vez de cerrar la app).
    DeepLinkService.openPending();
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    final ok = await AuthService.instance.hydrateSession();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      DeepLinkService.openPending();
    } else {
      setState(() => _retrying = false);
      MessengerService.info('Sigues sin conexión. Intenta de nuevo.');
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _LoadMode.offlineRetry) {
      return SessionRetryScreen(onRetry: _retry, onSignOut: _signOut, busy: _retrying);
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
