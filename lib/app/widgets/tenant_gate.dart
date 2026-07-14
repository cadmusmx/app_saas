import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

/// Guard de sesión unificado.
/// Sin sesión válida → /login (empresa pre-llenada desde TenantContext/TenantStorage).
/// Con sesión → muestra [child].
class TenantGate extends StatelessWidget {
  final Widget child;
  const TenantGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (!auth.isAuthenticated || !auth.isTokenValid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).pushReplacementNamed(AppRoutes.login),
      );
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return child;
  }
}
