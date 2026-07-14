import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/core/services/connectivity_service.dart';

class ConnectionStatusListener extends StatefulWidget {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  final Widget child;
  const ConnectionStatusListener({required this.child, super.key});

  @override
  State<ConnectionStatusListener> createState() => _ConnectionStatusListenerState();
}

class _ConnectionStatusListenerState extends State<ConnectionStatusListener> {
  bool _wasOffline = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, service, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final messenger = ConnectionStatusListener.scaffoldMessengerKey.currentState;
          if (messenger == null) return;
          final isOffline = !service.hasConnection;

          if (isOffline && !_wasOffline) {
            messenger.removeCurrentMaterialBanner();
            messenger.showMaterialBanner(
              MaterialBanner(
                backgroundColor: Colors.red.shade700,
                content: const Text('Sin conexión a Internet', style: TextStyle(color: Colors.white)),
                actions: [
                  TextButton(
                    onPressed: () => messenger.hideCurrentMaterialBanner(),
                    child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            _wasOffline = true;
          } else if (!isOffline && _wasOffline) {
            messenger.removeCurrentMaterialBanner();
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: Colors.green.shade700,
                content: const Text('Conexión restaurada', style: TextStyle(color: Colors.white)),
              ),
            );
            _wasOffline = false;
          }
        });

        return widget.child;
      },
    );
  }
}
