import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/app/widgets/drawer_lateral.dart';
import 'package:gaso_tenant_app/app/widgets/menu_registry.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/services/fcm_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/services/session_service.dart';
import 'package:gaso_tenant_app/features/notifications/data/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NotificationService _notificationService = NotificationService();
  final SessionService _sessionService = SessionService();

  @override
  void initState() {
    super.initState();
    if (Config.fireBaseToken) {
      FcmService().initialize(onToken: _saveAndSendFcmToken, onMessage: _handleNotification);
    }
  }

  /// Método centralizado para manejar todas las notificaciones
  void _handleNotification(RemoteMessage message, {required bool fromBackground}) {
    if (!mounted) return;
    final title = message.notification?.title ?? 'Nueva notificación';
    final body = message.notification?.body ?? '';
    final data = message.data;
    _notificationService.saveNotification(title, body, data['timestamp']);
    if (fromBackground) {
      MessengerService.info('$title${body.isNotEmpty ? '\n$body' : ''}', duration: 6);
      _handleNotificationNavigation(data);
    } else {
      MessengerService.info('$title${body.isNotEmpty ? ': $body' : ''}');
    }
  }

  /// Navegar a diferentes pantallas según el tipo de notificación
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final notificationType = data['type'];
    if (notificationType == 'liability') {
      Navigator.pushNamed(context, AppRoutes.vehicleLiabilityList);
    }
    if (notificationType == 'expense') {
      Navigator.pushNamed(context, AppRoutes.operationExpensesList);
    }
    if (notificationType == 'vacation') {
      Navigator.pushNamed(context, AppRoutes.vacationLeave);
    }
  }

  Future<void> _saveAndSendFcmToken(String token) async {
    if (!mounted) return;
    if (!hasConnection(context)) return;
    final response = await _sessionService.updateTokenFirebase(token);
    if (response.success) {
      DebugLog.success("Token FCM Actualizado en Servidor: $token");
    } else {
      DebugLog.error('saveAndSendFcmToken: ${response.data}');
    }
  }

  void _handleMenuItemTap(MenuItem item) {
    Navigator.pushNamed(context, item.writeRoute);
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthContext>();
    final menuList = visibleMenu(auth).where((it) => auth.canWrite(it.viewCode)).toList();
    final user = auth.current;

    return Scaffold(
      appBar: const AppBarHeader('', showNotifications: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth == 0 || constraints.maxHeight == 0) {
            return const SizedBox.shrink();
          }
          if (menuList.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset("assets/images/logo.png", width: 64, color: colorScheme.onSurface),
                    Text('GASO MULTI-TENANT', style: textTheme.titleLarge),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: 'CONSULTE A ',
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w300),
                        children: <TextSpan>[
                          TextSpan(
                            text: user?.branding.displayName ?? 'SU TENANT',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' PARA SABER MÁS ACERCA DE LO QUE PUEDE LOGRAR'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
            itemCount: menuList.length,
            itemBuilder: (context, index) {
              final MenuItem item = menuList[index];
              return InkWell(
                onTap: () => _handleMenuItemTap(item),
                child: Card(
                  color: colorScheme.surfaceContainerLowest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(item.image, width: 32, height: 32, color: colorScheme.primary),
                        SizedBox(height: 8.0),
                        Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.description != null)
                          Text(
                            item.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      drawer: const DrawerLateral(),
    );
  }
}
