import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gaso_tenant_app/app/app.dart';
//import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/services/connectivity_service.dart';
import 'package:gaso_tenant_app/core/services/deep_link_service.dart';
import 'package:gaso_tenant_app/core/services/theme_service.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

/// Handler de notificaciones FCM en 2° plano (Android).
/// Debe ser una función top-level con `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // if (Config.fireBaseToken) {
  //   await Firebase.initializeApp();
  //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider.value(value: TenantContext.instance),
        ChangeNotifierProvider.value(value: AuthService.instance),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const GasoTenantApp(),
    ),
  );
  DeepLinkService(GasoTenantApp.navigatorKey).init();
}
