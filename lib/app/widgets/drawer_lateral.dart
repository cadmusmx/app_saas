import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/menu_registry.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
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
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthContext>();
    final groups = groupedMenu(auth); // Map<group, List<MenuItem>> ya filtrado y ORDENADO
    final user = auth.current;

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
                Consumer<TenantContext>(
                  builder: (_, ctx, _) => Text(
                    user?.branding.displayName ?? TenantContext.instance.current?.name ?? '',
                    style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: Text(
                    (user?.user.name ?? '').toUpperCase(),
                    style: textTheme.titleSmall?.copyWith(color: colorScheme.onPrimary),
                  ),
                ),
                Flexible(
                  child: Text(
                    (user?.profile.name ?? '').toUpperCase(),
                    style: textTheme.titleSmall?.copyWith(color: colorScheme.onPrimary),
                  ),
                ),
                Expanded(child: SizedBox.shrink()),
                Row(
                  spacing: 4,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset("assets/images/logo.png", width: 16, color: colorScheme.onPrimary),
                    Text('MULTI-TENANT', style: textTheme.titleSmall?.copyWith(color: colorScheme.onPrimary)),
                  ],
                ),
              ],
            ),
          ),
          DrawerListTile(
            DrawerOption(path: AppRoutes.profile, title: 'Perfil', icon: Icons.person_sharp, released: false),
            colorScheme.primary,
          ),
          ...groups.entries.map(
            (groupEntry) => groupEntry.value.length == 1
                ? DrawerListTile(
                    DrawerOption(
                      path: groupEntry.value.first.readRoute,
                      title: groupEntry.value.first.label,
                      icon: groupEntry.value.first.icon,
                    ),
                    colorScheme.primary,
                  )
                : ExpansionTile(
                    shape: const Border(),
                    title: Text(kGroupLabels[groupEntry.key] ?? 'MÁS OPCIONES', style: textTheme.bodyMedium),
                    children: groupEntry.value
                        .map(
                          (item) => DrawerListTile(
                            DrawerOption(path: item.readRoute, title: item.label, icon: item.icon),
                            colorScheme.primary,
                          ),
                        )
                        .toList(),
                  ),
          ),
          DrawerListTile(
            DrawerOption(path: AppRoutes.support, title: 'Soporte técnico', icon: Icons.support_agent),
            colorScheme.primary,
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
          Divider(height: 32),
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
