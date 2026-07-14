import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';

class ConnectivityService with ChangeNotifier {
  bool _hasConnection = true;
  bool get hasConnection => _hasConnection;

  late StreamSubscription _subscription;

  ConnectivityService() {
    _subscription = Connectivity()
        .onConnectivityChanged
        .map((results) => results.isNotEmpty ? results.first : ConnectivityResult.none)
        .listen(_updateConnectionStatus);

    _checkNow();
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    bool previous = _hasConnection;
    _hasConnection = await InternetConnectionChecker().hasConnection || await _canLookUp();
    if (previous != _hasConnection) notifyListeners();
  }

  Future<void> _checkNow() async {
    _hasConnection = await InternetConnectionChecker().hasConnection || await _canLookUp();
    notifyListeners();
  }

  Future<bool> _canLookUp() async {
    try {
      final result = await InternetAddress.lookup('gaso-erp.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      DebugLog.error('Error verificando conexión: $e');
      return false;
    }
  }

  bool checkConnection(BuildContext context) {
    if (!hasConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conexión. Operación cancelada.')),
      );
    }
    return hasConnection;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
