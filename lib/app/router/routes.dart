import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/app/widgets/rbac_gate.dart';
import 'package:gaso_tenant_app/app/widgets/tenant_gate.dart';
import 'package:gaso_tenant_app/app/widgets/menu_registry.dart';
import 'package:gaso_tenant_app/features/auth/presentation/load_screen.dart';
import 'package:gaso_tenant_app/features/auth/presentation/login_screen.dart';
import 'package:gaso_tenant_app/features/auth/presentation/mfa_screen.dart';
import 'package:gaso_tenant_app/features/auth/presentation/mfa_setup_screen.dart';
import 'package:gaso_tenant_app/features/support/presentation/support_screen.dart';
import 'package:gaso_tenant_app/features/home/presentation/home_screen.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_validation.dart';
import 'package:gaso_tenant_app/features/material_validation/presentation/material_validation_detail.dart';
import 'package:gaso_tenant_app/features/material_validation/presentation/material_validation_form.dart';
import 'package:gaso_tenant_app/features/material_validation/presentation/material_validation_list.dart';

class AppRoutes {
  AppRoutes._();

  // Públicas
  static const String load = '/load';
  static const String login = '/login';
  static const String mfa = '/mfa';
  static const String mfaSetup = '/mfa-setup';

  // Protegidas
  static const String home = '/home';
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
  AppRoutes.profile: (_) => const TenantGate(child: EnProceso()),
  AppRoutes.support: (_) => const TenantGate(child: SupportScreen()),

  // vacation comparte ruta lista/alta: entrada por lectura, acciones por bit en el feature (S5)
  AppRoutes.vacationLeave: (_) => const RbacGate(viewCode: 'vacation', child: EnProceso()),
  AppRoutes.weeklyMileage: (_) {
    return const RbacGate(viewCode: 'weekly_mileage', require: kWriteMask, child: EnProceso());
  },
  AppRoutes.weeklyMileageList: (_) => const RbacGate(viewCode: 'weekly_mileage', child: EnProceso()),
  AppRoutes.vehicleLiability: (_) {
    return const RbacGate(viewCode: 'vehicle_liability', require: kWriteMask, child: EnProceso());
  },
  AppRoutes.vehicleLiabilityList: (_) => const RbacGate(viewCode: 'vehicle_liability', child: EnProceso()),
  AppRoutes.fuelRequest: (_) {
    return const RbacGate(viewCode: 'gasoline_receipt', require: kWriteMask, child: EnProceso());
  },
  AppRoutes.fuelRequestList: (_) => const RbacGate(viewCode: 'gasoline_receipt', child: EnProceso()),
  AppRoutes.materialValidation: (_) {
    return const RbacGate(viewCode: 'material_validation', require: kWriteMask, child: MaterialValidationForm());
  },
  AppRoutes.materialValidationList: (_) => const RbacGate(viewCode: 'material_validation', child: MaterialValidationList()),
  AppRoutes.materialValidationDetail: (context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    final folio = args is String ? args : null;
    final material = args is MaterialValidation ? args : null;

    return RbacGate(viewCode: 'material_validation', child: MaterialValidationDetail(folio: folio, materialValidation: material));
  },
  AppRoutes.materialLogistics: (context) {
    // final args = ModalRoute.of(context)!.settings.arguments;
    // final record = args is MaterialLogistics ? args : null;

    // child: MaterialLogisticsShell(record: record)
    return const RbacGate(viewCode: 'material_logistics', require: kWriteMask, child: EnProceso());
  },
  AppRoutes.materialLogisticsList: (_) => const RbacGate(viewCode: 'material_logistics', child: EnProceso()),
  AppRoutes.operationExpenses: (_) {
    return const RbacGate(viewCode: 'requests_expenses', require: kWriteMask, child: EnProceso());
  },
  AppRoutes.operationExpensesList: (_) => const RbacGate(viewCode: 'requests_expenses', child: EnProceso()),
  AppRoutes.vehicleExpenses: (_) {
    return const RbacGate(viewCode: 'vehicle_expense_control', require: kWriteMask, child: EnProceso());
  },
  AppRoutes.vehicleExpensesList: (_) => const RbacGate(viewCode: 'vehicle_expense_control', child: EnProceso()),
};

class EnProceso extends StatelessWidget {
  const EnProceso({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarHeader('NO DISPONIBLE'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(child: Text('EN PROCESO...'));
        },
      ),
    );
  }
}
