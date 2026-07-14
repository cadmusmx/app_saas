import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

enum _SetupState { idle, loading, error }

/// Pantalla de configuración MFA para usuarios que aún no tienen TOTP activado.
/// Muestra el QR (otpauth://) y la clave manual para agregar en Google Authenticator.
/// Tras verificar el primer código, obtiene un challengeId y navega a MfaScreen.
class MfaSetupScreen extends StatefulWidget {
  final String username;
  final String password;
  final String setupId;
  final String? secretCode; // clave manual TOTP
  final String? qrCodeUrl;  // otpauth:// URI

  const MfaSetupScreen({
    super.key,
    required this.username,
    required this.password,
    required this.setupId,
    this.secretCode,
    this.qrCodeUrl,
  });

  @override
  State<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

class _MfaSetupScreenState extends State<MfaSetupScreen> {
  final _codeController = TextEditingController();
  _SetupState _state = _SetupState.idle;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() { _state = _SetupState.loading; _errorMessage = null; });

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.setupMfa(
      widget.username,
      widget.password,
      widget.setupId,
      code,
    );

    if (!mounted) return;

    switch (result.status) {
      // Setup verificado → authService ya obtuvo challengeId → ir a MfaScreen
      case AuthStatus.mfaRequired:
        Navigator.pushReplacementNamed(context, AppRoutes.mfa, arguments: {
          'username':    widget.username,
          'password':    widget.password,
          'challengeId': result.sessionChallenge ?? '',
        });

      case AuthStatus.failure:
        setState(() {
          _state        = _SetupState.error;
          _errorMessage = result.errorMessage;
        });
        _codeController.clear();

      case AuthStatus.success:
      case AuthStatus.mfaSetupRequired:
        Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  Future<void> _copySecret() async {
    final secret = widget.secretCode;
    if (secret == null) return;
    await Clipboard.setData(ClipboardData(text: secret));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clave copiada al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isLoading   = _state == _SetupState.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Activar verificación en dos pasos')),
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
                Icon(Icons.security, size: 64, color: colorScheme.primary),

                const Text(
                  'Configura tu app autenticadora',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),

                const Text(
                  'Abre Google Authenticator, Authy o cualquier app TOTP y agrega una nueva cuenta escaneando el código QR o ingresando la clave manual.',
                  textAlign: TextAlign.center,
                ),

                // QR generado desde el otpauth:// URI
                if (widget.qrCodeUrl != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Escanea este código QR con tu app autenticadora',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: QrImageView(
                            data: widget.qrCodeUrl!,
                            version: QrVersions.auto,
                            size: 220,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Clave manual con botón de copia
                if (widget.secretCode != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            widget.secretCode!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copiar clave',
                          onPressed: _copySecret,
                        ),
                      ],
                    ),
                  ),

                const Text(
                  'Una vez agregada, ingresa el código de 6 dígitos que genera tu app para confirmar la configuración.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),

                TextField(
                  controller: _codeController,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    labelText: 'Código de verificación',
                    prefixIcon: const Icon(Icons.pin),
                    errorText: _state == _SetupState.error ? _errorMessage : null,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.go,
                  maxLength: 6,
                  autocorrect: false,
                  onSubmitted: (_) => _activate(),
                ),

                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton(
                    onPressed: _activate,
                    child: const Text('Activar verificación'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
