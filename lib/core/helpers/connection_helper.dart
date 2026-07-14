import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/core/services/connectivity_service.dart';

/// Indica el estado de la conexión a internet actual
bool hasConnection(BuildContext context) {
  final service = context.read<ConnectivityService>();
  return service.checkConnection(context);
}
