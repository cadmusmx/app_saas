import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/auth/perm_mask.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

// Guard de ruta con RBAC por capacidad. Envuelve el `child` de una ruta
// protegida y decide en este orden:
//   1. Sin sesión (token) válida           → redirige a /login.
//   2. Sesión pero RBAC no hidratado       → spinner (hidratación en curso; NO denegar aquí, sería un falso negativo).
//   3. Máscara insuficiente para `require` → AccessDeniedScreen (bloquea, no oculta).
//   4. OK                                  → child.
//
// `require`:
//   - rutas de lectura (lista/detalle) → Perm.r (por defecto)
//   - rutas de mutación (alta/edición) → kWriteMask (W|U|D) [menu_registry]

class RbacGate extends StatelessWidget {
  final String viewCode;
  final int require;
  final Widget child;

  const RbacGate({super.key, required this.viewCode, required this.child, this.require = Perm.r});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final session = context.watch<AuthContext>();

    // 1. Sin sesión válida → login.
    if (!auth.isAuthenticated || !auth.isTokenValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).pushReplacementNamed(AppRoutes.login));
      return const _GateBusy();
    }

    // 2. Autenticado pero la sesión RBAC aún no está hidratada (getMe en curso).
    if (session.current == null) return const _GateBusy();

    // 3. Permiso insuficiente para la capacidad exigida.
    if ((session.maskOf(viewCode) & require) == 0) return const AccessDeniedScreen();

    // 4. Autorizado.
    return child;
  }
}

class _GateBusy extends StatelessWidget {
  const _GateBusy();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Acceso denegado', style: textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'No tienes permiso para acceder a esta sección.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Volver')),
            ],
          ),
        ),
      ),
    );
  }
}
