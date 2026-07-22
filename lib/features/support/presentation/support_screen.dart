import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/tenant/tenant.dart';
import 'package:gaso_tenant_app/core/widgets/forms/dialogs.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/services/connectivity_service.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';
import 'package:gaso_tenant_app/features/support/data/health_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final SharedPreferences _preferences;
  String _lastClean = '';
  final String _lastCleanSPKey = 'lastCacheClear';
  List<String> _debugLogs = [];
  final _health = HealthService();
  String _version = '—';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((preferences) => {_preferences = preferences});
    _loadVersion();
    _getDebugLogs();
  }

  Future<void> _getDebugLogs() async {
    try {
      final debugLogs = await DebugLog.getDebugLogs();
      if (mounted) {
        setState(() {
          _debugLogs = debugLogs;
          _lastClean = _preferences.getString(_lastCleanSPKey) ?? '';
        });
      }
    } catch (e) {
      DebugLog.error('_initialize: $e');
    }
  }

  Future<void> _clearCache() async {
    try {
      final allEnumKeys = ['HARDCODED-KEY'];
      int noRemovedKeys = 0;
      for (var key in allEnumKeys) {
        bool removed = await _preferences.remove(key);
        if (!removed) {
          DebugLog.warning('_clearCache - $key no se pudo borrar');
          noRemovedKeys++;
        }
      }
      if (noRemovedKeys > 0) {
        await _getDebugLogs();
      }
    } catch (e) {
      DebugLog.error('_initialize: $e');
    } finally {
      if (mounted) {
        setState(() {
          _lastClean = 'Ultima vez el ${getCurrentFormattedDate('dd/MM/yyyy HH:mm')}';
        });
        _preferences.setString(_lastCleanSPKey, _lastClean);
      }
      MessengerService.info('Se limpio la cache');
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version}+${info.buildNumber}');
    }
  }

  Future<void> _testBff() async {
    try {
      setState(() => _loading = true);
      final res = await _health.check();
      if (res.success) {
        MessengerService.info('BFF Respuesta: OK 200');
      } else {
        MessengerService.error('BFF Error: ${res.message}');
      }
    } catch (e) {
      DebugLog.error('_testBff: $e');
      MessengerService.error('Sin respuesta del servidor');
    } finally {
      setState(() => _loading = false);
    }
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
    final bool online = context.watch<ConnectivityService>().hasConnection;
    final Tenant? tenant = context.watch<TenantContext>().current;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBarHeader('Soporte técnico', showNotifications: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
              child: Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoRow(label: 'Versión', _version),
                  InfoRow(label: 'Entorno', Config.appEnv.name),
                  InfoRow(
                    label: 'BFF',
                    Config.apiUrl,
                    actionIcon: Icons.cloud_sync,
                    onAction: _loading ? null : _testBff,
                  ),
                  InfoRow(label: 'Conectividad', online ? 'En línea' : 'Sin conexión'),
                  InfoRow(
                    label: 'Tenant',
                    tenant != null ? '${tenant.name} (${tenant.isActive ? 'Activo' : 'Inactivo'})' : '—',
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _clearCache,
                      icon: Icon(Icons.cached),
                      label: Text('Borrar cache'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(color: colorScheme.primary),
                      ),
                    ),
                  ),
                  Text(
                    'Los datos se actualizan al abrir un formulario.\n'
                    '$_lastClean',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                  ),
                  SectionTitle('Registro de alertas'),
                  if (_debugLogs.isNotEmpty) ...[
                    Text(
                      'Copiar y compartir con el equipo de soporte:',
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                    ),
                    SelectableText(
                      _debugLogs.join('\n'),
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.tertiary),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _debugLogs.join('\n')));
                        MessengerService.info('Logs copiados al portapapeles');
                      },
                    ),
                  ],
                  if (_debugLogs.isEmpty) Center(child: Text('No hay alertas registradas')),
                  SizedBox(height: 16),
                  if (_debugLogs.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          // Mostrar diálogo de confirmación antes de borrar los logs
                          final deleteLogs = await showOptionsDialog<bool>(
                            context,
                            'Borrar registros',
                            '¿Está seguro de que desea borrar todos los logs de depuración? Esta acción no se puede deshacer.',
                            {'No, cancelar': false, 'Si, borrar': true},
                          );
                          if (deleteLogs == true) {
                            DebugLog.clearLogs();
                            if (mounted) setState(() => _debugLogs = []);
                          }
                        },
                        icon: Icon(Icons.clear_all),
                        label: Text('Borrar registros'),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: Icon(Icons.logout),
                      label: Text('Cerrar sesión'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
