import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/connection_listener.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/services/theme_service.dart';
import 'package:gaso_tenant_app/features/auth/presentation/load_screen.dart';

/// Widget raíz de la aplicación.
///
/// Expone [navigatorKey] como `static final` para permitir navegación
/// programática desde fuera del árbol de widgets (usado por el handler
/// de deep links en `HomeScreen` y por servicios de notificación).
class GasoTenantApp extends StatelessWidget {
  const GasoTenantApp({super.key});

  /// Clave global del Navigator, usada para navegar desde código que no
  /// tiene acceso a un `BuildContext` (deep links, FCM handlers).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Color _seed(String? hex) {
    final h = (hex ?? Branding.defaultPrimaryColor).replaceFirst('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v == null ? Colors.blueAccent : Color(v);
  }

  ThemeData _buildTheme(BuildContext context, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed(context.watch<AuthContext>().branding?.primaryColor),
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.content
      ),
      cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 8.0,
        horizontalTitleGap: 8.0,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
      chipTheme: ChipThemeData(
        elevation: 0,
        pressElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: Config.appEnv == AppEnv.dev,
          theme: _buildTheme(context, Brightness.light),
          darkTheme: _buildTheme(context, Brightness.dark),
          // Deshabilita la restauración automática de estado de navegación
          // el que intenta cargar la ruta "/" al volver desde deep link.
          restorationScopeId: null,
          themeMode: themeService.themeMode,
          locale: const Locale('es', 'MX'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('es', 'MX'), Locale('es'), Locale('en')],
          scaffoldMessengerKey: ConnectionStatusListener.scaffoldMessengerKey,
          builder: (context, child) {
            return Overlay(
              key: MessengerService.overlayKey,
              initialEntries: [
                OverlayEntry(builder: (_) => ConnectionStatusListener(child: child ?? const SizedBox.shrink())),
              ],
            );
          },
          initialRoute: AppRoutes.load,
          // Fallback para rutas no encontradas (incluyendo "/")
          onUnknownRoute: (settings) => MaterialPageRoute(builder: (_) => const LoadScreen()),
          routes: appRoutes,
        );
      },
    );
  }
}
