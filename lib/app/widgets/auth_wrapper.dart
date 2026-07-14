import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';


class AuthWrapper extends StatelessWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Si el usuario NO está autenticado, redirigir a login
    if (!authService.isAuthenticated || !authService.isTokenValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).pushReplacementNamed(AppRoutes.login));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Usuario autenticado, mostrar el contenido
    return child;
  }
}
