import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/widgets/tenant_gate.dart';
import 'package:gaso_tenant_app/features/auth/presentation/load_screen.dart';
import 'package:gaso_tenant_app/features/auth/presentation/login_screen.dart';
import 'package:gaso_tenant_app/features/auth/presentation/mfa_screen.dart';
import 'package:gaso_tenant_app/features/auth/presentation/mfa_setup_screen.dart';
import 'package:gaso_tenant_app/features/health/presentation/health_screen.dart';
import 'package:gaso_tenant_app/features/home/presentation/home_screen.dart';

class AppRoutes {
  AppRoutes._();

  // Públicas
  static const String load = '/load';
  static const String login = '/login';
  static const String mfa = '/mfa';
  static const String mfaSetup = '/mfa-setup';

  // Protegidas (TenantGate verifica sesión)
  static const String home = '/home';
  static const String health = '/health';
  static const String profile = '/profile';
  static const String vacationLeave = '/vacation-leave';
  static const String support = '/support';

  static const String weeklyMileage = '/weekly-mileage';
  static const String weeklyMileageList = '/weekly-mileage-list';

  static const String fuelRequest = '/fuel-request';
  static const String fuelRequestList = '/fuel-request-list';

  static const String vehicleLiability = '/vehicle-liability';
  static const String vehicleLiabilityList = '/vehicles-liability-list';

  static const String materialValidation = '/material-validation';
  static const String materialValidationList = '/material-validation-list';
  static const String materialValidationDetail = '/material-validation-detail';

  static const String materialLogistics = '/material-logistics';
  static const String materialLogisticsList = '/material-logistics-list';

  static const String operationExpenses = '/operation-expenses';
  static const String operationExpensesList = '/operation-expenses-list';
  static const String vehicleExpenses = '/vehicle-expenses';
  static const String vehicleExpensesList = '/vehicle-expenses-list';
}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.load: (_) => const LoadScreen(),

  // Login acepta {initialSlug} como argumento de ruta (ej. desde deep link)
  AppRoutes.login: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String? initialSlug;
    if (args is Map) {
      initialSlug = args['initialSlug'] as String?;
    } else if (args is String) {
      final decoded = jsonDecode(args);
      initialSlug = decoded['initialSlug'] as String?;
    }
    return LoginScreen(initialSlug: initialSlug);
  },

  AppRoutes.mfa: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map ? args : <String, String?>{};
    return MfaScreen(
      username: (map['username'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      challengeId: (map['challengeId'] as String?) ?? '',
    );
  },

  AppRoutes.mfaSetup: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map ? args : <String, String?>{};
    return MfaSetupScreen(
      username: (map['username'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      setupId: (map['setupId'] as String?) ?? '',
      secretCode: map['secretCode'] as String?,
      qrCodeUrl: map['qrCodeUrl'] as String?,
    );
  },

  // Protegidas: TenantGate unificado (verifica sesión; si no → /login)
  AppRoutes.home: (_) => const TenantGate(child: HomeScreen()),
  AppRoutes.health: (_) => const TenantGate(child: HealthScreen()),
  AppRoutes.profile: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.vacationLeave: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.support: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.weeklyMileage: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.weeklyMileageList: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.vehicleLiability: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.vehicleLiabilityList: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.fuelRequest: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.fuelRequestList: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.materialValidation: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.materialValidationList: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.materialValidationDetail: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.materialLogistics: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.materialLogisticsList: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.operationExpenses: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.operationExpensesList: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.vehicleExpenses: (_) => const TenantGate(child: Text('En proceso')),
  AppRoutes.vehicleExpensesList: (_) => const TenantGate(child: Text('En proceso')),
};
