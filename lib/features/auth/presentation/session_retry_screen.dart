import 'package:flutter/material.dart';

/// Cold-start offline: el token es válido pero `/api/me` no cargó (típicamente sin conexión al reabrir).
/// En vez de entrar a un home vacío, se ofrece reintentar la hidratación o cerrar sesión..
class SessionRetryScreen extends StatelessWidget {
  /// Re-intenta `hydrateSession()`. Navega a home si tiene éxito (lo decide el caller).
  final Future<void> Function() onRetry;

  /// Cierra sesión y vuelve a login.
  final Future<void> Function() onSignOut;

  /// Muestra spinner en el botón mientras el reintento está en curso.
  final bool busy;

  const SessionRetryScreen({super.key, required this.onRetry, required this.onSignOut, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text('Sin conexión', style: textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'No pudimos cargar tu sesión. Verifica tu conexión e intenta de nuevo.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : onRetry,
                icon: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(busy ? 'Re-intentando...' : 'Reintentar'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: busy ? null : onSignOut, child: const Text('Cerrar sesión')),
            ],
          ),
        ),
      ),
    );
  }
}
