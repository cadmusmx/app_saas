import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_storage.dart';
import 'package:gaso_tenant_app/core/widgets/lists/tiles.dart';
import 'package:gaso_tenant_app/core/services/theme_service.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

class DrawerLateral extends StatefulWidget implements PreferredSizeWidget {
  const DrawerLateral({super.key});

  @override
  State<DrawerLateral> createState() => _DrawerLateralState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _DrawerLateralState extends State<DrawerLateral> {
  final List<DrawerOption> _options = [
    DrawerOption(path: AppRoutes.health, title: 'Estado', icon: Icons.medical_services),
    DrawerOption(path: AppRoutes.profile, title: 'Perfil', icon: Icons.person_sharp),
    DrawerOption(path: AppRoutes.vacationLeave, title: 'Vacaciones y permisos', icon: Icons.beach_access_sharp),
    DrawerOption(path: AppRoutes.support, title: 'Soporte técnico', icon: Icons.support_agent),
  ];
  final List<DrawerOption> _vehiclesOptions = [
    DrawerOption(path: AppRoutes.weeklyMileageList, title: 'Kilometraje semanal', icon: Icons.speed_sharp),
    DrawerOption(
      path: AppRoutes.fuelRequestList,
      title: 'Solicitudes de gasolina',
      icon: Icons.local_gas_station_sharp,
    ),
    DrawerOption(path: AppRoutes.vehicleLiabilityList, title: 'Responsivas vehiculares', icon: Icons.fact_check_sharp),
    DrawerOption(path: AppRoutes.vehicleExpensesList, title: 'Gastos vehiculares', icon: Icons.directions_car),
  ];
  final List<DrawerOption> _expensesOptions = [
    DrawerOption(
      path: AppRoutes.operationExpensesList,
      title: 'Gastos de operación',
      icon: Icons.business_center_sharp,
    ),
    DrawerOption(title: 'Gastos de viaje', icon: Icons.flight_sharp, released: false),
  ];
  final List<DrawerOption> _warehouseOptions = [
    DrawerOption(path: AppRoutes.materialValidationList, title: 'Validación de material', icon: Icons.inventory_sharp),
    DrawerOption(path: AppRoutes.materialLogisticsList, title: 'Logística de material', icon: Icons.move_up_sharp),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.of(context);
    final TextTheme textTheme = TextTheme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  spacing: 8,
                  children: [
                    Image.asset("assets/images/logo.png", width: 32, height: 32, color: colorScheme.onPrimary),
                    Text(
                      'GASO',
                      style: textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Text(
                    'NOMBRE DE USUARIO',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: Text(
                    'PUESTO',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary),
                  ),
                ),
                SizedBox(height: 32),
                Consumer<TenantContext>(
                  builder: (_, ctx, _) => Text(
                    ctx.current?.name.toUpperCase() ?? '',
                    style: textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ..._options.map((option) => DrawerListTile(option, colorScheme.primary)),
          ExpansionTile(
            shape: const Border(),
            title: Text('FLOTILLAS', style: textTheme.bodyMedium),
            children: _vehiclesOptions.map((option) => DrawerListTile(option, colorScheme.primary)).toList(),
          ),
          ExpansionTile(
            shape: const Border(),
            title: Text('GASTOS', style: textTheme.bodyMedium),
            children: _expensesOptions.map((option) => DrawerListTile(option, colorScheme.primary)).toList(),
          ),
          ExpansionTile(
            shape: const Border(),
            title: Text('ALMACÉN', style: textTheme.bodyMedium),
            children: _warehouseOptions.map((option) => DrawerListTile(option, colorScheme.primary)).toList(),
          ),
          Consumer<ThemeService>(
            builder: (context, themeService, _) {
              return SwitchListTile(
                secondary: Icon(themeService.isDark ? Icons.dark_mode : Icons.light_mode, color: colorScheme.primary),
                title: Text('MODO OSCURO', overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
                value: themeService.isDark,
                onChanged: (_) => themeService.toggleDark(),
              );
            },
          ),
          Divider(),
          ListTile(
            title: Text('CAMBIAR EMPRESA', style: textTheme.bodyMedium),
            trailing: Icon(Icons.swap_horiz, color: colorScheme.primary),
            onTap: () async {
              Navigator.pop(context);
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.logout();
              await TenantStorage().clear();
              TenantContext.instance.clearTenant();
              if (context.mounted) {
                // Login sin empresa pre-llenada → usuario escribe nuevo dominio
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            },
          ),
          ListTile(
            title: Text('CERRAR SESIÓN', style: textTheme.bodyMedium),
            onTap: () async {
              Navigator.pop(context);
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.logout();
              // TenantGate reacciona al cambio; navegación explícita como respaldo
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            },
            trailing: Icon(Icons.logout, color: colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
