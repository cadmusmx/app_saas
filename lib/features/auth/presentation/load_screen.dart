import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_storage.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

/// Pantalla de arranque: carga datos de disco y delega la lógica de
/// redirección a TenantGate (sin tenant → picker) y AuthWrapper (sin auth → login).
class LoadScreen extends StatefulWidget {
  const LoadScreen({super.key});

  @override
  State<LoadScreen> createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    /// 1. Restaurar tenant desde disco a memoria (para pre-llenar el login)
    /// LoadScreen No pisa un slug puesto por el deep link
    final savedTenant = await TenantStorage().load();
    if (savedTenant != null && TenantContext.instance.current == null) {
      TenantContext.instance.setTenant(savedTenant);
    }

    /// 2. Esperar a que AuthService termine de leer secure storage
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
    /// 3. Siempre navega a home — TenantGate y AuthWrapper deciden qué mostrar
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
