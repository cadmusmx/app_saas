import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/app/widgets/drawer_lateral.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/services/fcm_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/services/session_service.dart';
import 'package:gaso_tenant_app/features/home/domain/home.dart';
import 'package:gaso_tenant_app/features/notifications/data/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NotificationService _notificationService = NotificationService();
  final SessionService _sessionService = SessionService();

  List<MenuOption> options = [
    MenuOption('KILOMETRAJE SEMANAL', image: 'assets/icons/odometer.png', path: AppRoutes.weeklyMileage),
    MenuOption('SOLICITUD DE GASOLINA', image: 'assets/icons/gas-station.png', path: AppRoutes.fuelRequest),
    MenuOption(
      'RESPONSIVA VEHICULAR',
      description: 'RESPONSABILIDAD Y SERVICIOS',
      image: 'assets/icons/car-document.png',
      path: AppRoutes.vehicleLiability,
    ),
    MenuOption('GASTO DE OPERACIÓN', image: 'assets/icons/budget.png', path: AppRoutes.operationExpenses),
    MenuOption('GASTO VEHICULAR', image: 'assets/icons/budget.png', path: AppRoutes.vehicleExpenses),
    MenuOption(
      'VALIDACIÓN DE MATERIAL',
      image: 'assets/icons/package.png',
      description: 'ENTRADA Y SALIDA',
      path: AppRoutes.materialValidation,
    ),
    MenuOption(
      'LOGÍSTICA DE MATERIAL',
      image: 'assets/icons/logistics.png',
      description: 'RECEPCIÓN Y ENTREGA',
      path: AppRoutes.materialLogistics,
    ),
  ];

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

  void _handleOptionTap(MenuOption option) {
    if (!option.released) {
      return MessengerService.info('En proceso');
    }
    if (option.path != null) {
      Navigator.pushNamed(context, option.path!);
    } else {
      option.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppBarHeader(null, showNotifications: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth == 0 || constraints.maxHeight == 0) {
            return const SizedBox.shrink();
          }
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final MenuOption option = options[index];
              return InkWell(
                onTap: () => _handleOptionTap(option),
                child: Card(
                  color: colorScheme.surfaceContainerLowest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(option.image, width: 32, height: 32, color: colorScheme.primary),
                        SizedBox(height: 8.0),
                        Text(
                          option.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (option.description != null)
                          Text(
                            option.description ?? 'GASO COMUNICACIONES',
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
