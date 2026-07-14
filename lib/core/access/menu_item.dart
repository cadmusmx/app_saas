import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';

class MenuItem {
  final String group; // menuGroup de /api/me
  final String viewCode; // key en views{}
  final String label;
  final IconData icon;
  final String readRoute; // lista — destino del menú; guard: Perm.r
  final String writeRoute; // alta/edición — guard: Perm.w|u|d
  const MenuItem(this.group, this.viewCode, this.label, this.icon, this.readRoute, this.writeRoute);
}

const kMobileMenu = <MenuItem>[
  MenuItem(
    'warehouses',
    'material_logistics',
    'Logística de Material',
    Icons.local_shipping,
    AppRoutes.materialLogisticsList,
    AppRoutes.materialLogistics,
  ),
  MenuItem(
    'warehouses',
    'material_validation',
    'Validación de Material',
    Icons.fact_check,
    AppRoutes.materialValidationList,
    AppRoutes.materialValidation,
  ),
  MenuItem(
    'human_capital',
    'vacation',
    'Vacaciones',
    Icons.beach_access,
    AppRoutes.vacationLeave,
    AppRoutes.vacationLeave,
  ),
  MenuItem(
    'operating_expenses',
    'requests_expenses',
    'Solicitudes de Gastos',
    Icons.request_quote,
    AppRoutes.operationExpensesList,
    AppRoutes.operationExpenses,
  ),
  MenuItem(
    'vehicles',
    'gasoline_receipt',
    'Comprobantes de Gasolina',
    Icons.local_gas_station,
    AppRoutes.fuelRequestList,
    AppRoutes.fuelRequest,
  ),
  MenuItem(
    'vehicles',
    'vehicle_expense_control',
    'Control de Gastos Vehicular',
    Icons.payments,
    AppRoutes.vehicleExpensesList,
    AppRoutes.vehicleExpenses,
  ),
  MenuItem(
    'vehicles',
    'vehicle_liability',
    'Responsivas Vehiculares',
    Icons.assignment,
    AppRoutes.vehicleLiabilityList,
    AppRoutes.vehicleLiability,
  ),
  MenuItem(
    'vehicles',
    'weekly_mileage',
    'Kilometraje Semanal',
    Icons.speed,
    AppRoutes.weeklyMileageList,
    AppRoutes.weeklyMileage,
  ),
];
