import 'package:flutter/material.dart';

import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/auth/perm_mask.dart';

// Registro estático de las vistas móviles (VISTAS-APP = SI).
// Estar en `kMobileMenu` ES el filtro 4 ("disponible en la app"):
// no hace falta una lista aparte.
// Alimenta AMBAS superficies (drawer + grid de home) para no duplicar el gate RBAC.
//
// Cada vista expone DOS rutas con gate por capacidad:
//   - readRoute  (lista/detalle) → destino del menú, gate Perm.r
//   - writeRoute (alta/edición)  → gate kWriteMask (W|U|D)
//
// Todas navegan a una pantalla real (placeholder "en proceso" mientras no aterrice el feature).
// No hay estado "Próximamente"/deshabilitado en S3.

/// Máscara que habilita una ruta de mutación (cualquier bit W/U/D).
const int kWriteMask = Perm.w | Perm.u | Perm.d;

class MenuItem {
  final String group; // menuGroup de /api/me
  final String viewCode; // key en views{}
  final String label;
  final String readRoute; // gate: Perm.r
  final String writeRoute; // gate: kWriteMask
  final IconData icon;
  final String? description;

  const MenuItem(
    this.group,
    this.viewCode,
    this.label,
    this.readRoute,
    this.writeRoute, {
    required this.icon,
    this.description,
  });
}

class MenuGroup {
  final String groupName;
  final List<MenuItem> menuList;
  MenuGroup(this.groupName, this.menuList);
}

/// Etiquetas y orden de los grupos en el shell.
const Map<String, String> kGroupLabels = {
  'warehouses': 'ALMACENES',
  'human_capital': 'CAPITAL HUMANO',
  'operating_expenses': 'GASTOS DE OPERACIÓN',
  'vehicles': 'FLOTILLAS',
};

const List<String> kGroupOrder = ['warehouses', 'human_capital', 'operating_expenses', 'vehicles'];

const List<MenuItem> kMobileMenu = [
  MenuItem(
    'vehicles',
    'gasoline_receipt',
    'COMPROBANTES DE GASOLINA',
    AppRoutes.fuelRequestList,
    AppRoutes.fuelRequest,
    icon: Icons.local_gas_station_sharp,
  ),
  MenuItem(
    'vehicles',
    'vehicle_expense_control',
    'GASTOS VEHICULARES',
    AppRoutes.vehicleExpensesList,
    AppRoutes.vehicleExpenses,
    icon: Icons.payments,
  ),
  MenuItem(
    'vehicles',
    'vehicle_liability',
    'RESPONSIVAS VEHICULARES',
    AppRoutes.vehicleLiabilityList,
    AppRoutes.vehicleLiability,
    icon: Icons.fact_check_sharp,
    description: 'RESPONSABILIDAD Y SERVICIOS',
  ),
  MenuItem(
    'vehicles',
    'weekly_mileage',
    'KILOMETRAJE SEMANAL',
    AppRoutes.weeklyMileageList,
    AppRoutes.weeklyMileage,
    icon: Icons.speed_sharp,
  ),
  MenuItem(
    'human_capital',
    'vacation',
    'VACACIONES Y PERMISOS',
    AppRoutes.vacationLeave,
    AppRoutes.vacationLeave,
    icon: Icons.beach_access_sharp,
  ),
  MenuItem(
    'operating_expenses',
    'requests_expenses',
    'SOLICITUDES DE GASTOS',
    AppRoutes.operationExpensesList,
    AppRoutes.operationExpenses,
    icon: Icons.request_quote_sharp,
  ),
  MenuItem(
    'warehouses',
    'material_logistics',
    'LOGÍSTICA DE MATERIAL',
    AppRoutes.materialLogisticsList,
    AppRoutes.materialLogistics,
    icon: Icons.move_up_sharp,
    description: 'RECEPCIÓN Y ENTREGA A VARIOS SITIOS',
  ),
  MenuItem(
    'warehouses',
    'material_validation',
    'VALIDACIÓN DE MATERIAL',
    AppRoutes.materialValidationList,
    AppRoutes.materialValidation,
    icon: Icons.inventory_sharp,
    description: 'ENTRADA Y SALIDA POR PROYECTO',
  ),
];

// Filtros
// Cadena completa (una vista es visible si y solo si):
//   1. plan:     planMenuGroups.contains(group)   ─┐
//   2. settings: menuGroups[group] == true         ├─ AuthContext.isGroupEnabled
//   3. permiso:  Perm.hasRead(views[code].mask)    ── AuthContext.hasView
//   4. app:      estar en kMobileMenu               ── implícito por iterar aquí
// Además: el grupo `dashboard` se excluye siempre.

bool _isVisible(AuthContext auth, MenuItem it) =>
    it.group != 'dashboard' && auth.isGroupEnabled(it.group) && auth.hasView(it.viewCode);

/// Vistas visibles, en el orden declarado en `kMobileMenu`.
List<MenuItem> visibleMenu(AuthContext auth) => kMobileMenu.where((it) => _isVisible(auth, it)).toList(growable: false);

/// Vistas visibles agrupadas y ordenadas por `kGroupOrder`. Solo incluye
/// grupos con ≥1 vista visible (grupos vacíos no se muestran).
List<MenuGroup> groupedMenu(AuthContext auth) {
  final visible = visibleMenu(auth);
  final List<MenuGroup> out = [];
  for (final group in kGroupOrder) {
    final items = visible.where((it) => it.group == group).toList(growable: false);
    if (items.isNotEmpty) out.add(MenuGroup(group, items));
  }
  out.sort((mg1, mg2) => mg1.menuList.length - mg2.menuList.length);
  return out;
}
