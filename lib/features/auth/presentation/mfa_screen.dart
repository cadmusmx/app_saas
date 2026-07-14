import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

enum _MfaState { idle, loading, error }

class MfaScreen extends StatefulWidget {
  final String username;
  final String password;
  final String challengeId;

  const MfaScreen({super.key, required this.username, required this.password, required this.challengeId});

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _codeController = TextEditingController();
  _MfaState _state = _MfaState.idle;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _state = _MfaState.loading;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.verifyMfa(widget.username, widget.password, widget.challengeId, code);

    if (!mounted) return;

    switch (result.status) {
      case AuthStatus.success:
        Navigator.pushReplacementNamed(context, AppRoutes.home);

      case AuthStatus.failure:
        if (result.errorCode == 'MFA_EXPIRED') {
          MessengerService.info('El código expiró. Vuelve a iniciar sesión.');
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          return;
        }
        setState(() {
          _state = _MfaState.error;
          _errorMessage = result.errorMessage;
        });
        _codeController.clear();

      case AuthStatus.mfaRequired:
      case AuthStatus.mfaSetupRequired:
        Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isLoading = _state == _MfaState.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Verificación en dos pasos')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Icon(Icons.lock_outline, size: 64, color: colorScheme.primary),
                const Text(
                  'Verificación en dos pasos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const Text('Ingresa el código de 6 dígitos de tu app autenticadora.', textAlign: TextAlign.center),
                TextField(
                  controller: _codeController,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    labelText: 'Código de verificación',
                    prefixIcon: const Icon(Icons.pin),
                    errorText: _state == _MfaState.error ? _errorMessage : null,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.go,
                  maxLength: 6,
                  autocorrect: false,
                  onSubmitted: (_) => _verify(),
                ),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton(onPressed: _verify, child: const Text('Verificar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
