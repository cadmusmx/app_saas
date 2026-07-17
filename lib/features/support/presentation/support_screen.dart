import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/services/connectivity_service.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';
import 'package:gaso_tenant_app/features/support/data/health_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _health = HealthService();
  String _version = '—';
  bool _loading = false;
  String? _bffResult;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version}+${info.buildNumber}');
    }
  }

  Future<void> _testBff() async {
    setState(() {
      _loading = true;
      _bffResult = null;
    });
    final res = await _health.check();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _bffResult = res.success ? 'OK (${res.statusCode ?? 200})' : 'ERROR: ${res.message}';
    });
  }

  Future<void> _logout() async {
    await Provider.of<AuthService>(context, listen: false).logout();
    // TenantGate reacciona automáticamente al cambio de sesión → /login.
    // Navegación explícita como respaldo en caso de que el guard no alcance.
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().hasConnection;
    final tenant = context.watch<TenantContext>().current;

    return Scaffold(
      appBar: AppBarHeader('Soporte técnico'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ESTADO DE LA APP', style: TextTheme.of(context).titleSmall),
          _row('Versión', _version),
          _row('Entorno', Config.appEnv.name),
          _row('BFF', Config.apiUrl),
          _row('Conectividad', online ? 'En línea' : 'Sin conexión'),
          _row('Tenant', tenant != null ? '${tenant.name} (${tenant.isActive ? 'Activo' : 'Inactivo'})' : '—'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _testBff,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync),
            label: const Text('Probar BFF'),
          ),
          if (_bffResult != null) ...[const SizedBox(height: 16), Text(_bffResult!)],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}
