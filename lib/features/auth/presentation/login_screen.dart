import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/storage/preferences.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_storage.dart';
import 'package:gaso_tenant_app/features/auth/data/auth_service.dart';

enum _LoginState { idle, loading, error, blocked }

class LoginScreen extends StatefulWidget {
  /// Slug pre-llenado desde deep link o argumento de ruta.
  /// Tiene prioridad sobre TenantContext y TenantStorage.
  final String? initialSlug;
  const LoginScreen({super.key, this.initialSlug});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _empresaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _preferences = Preferences();
  final _tenantStorage = TenantStorage();

  bool _showPassword = false;
  bool _rememberMe = false;
  _LoginState _state = _LoginState.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // initialSlug (deep link / ruta) tiene prioridad; luego contexto en memoria
    _empresaController.text = widget.initialSlug ?? TenantContext.instance.current?.slug ?? '';
    _loadCredentials();
  }

  @override
  void dispose() {
    _empresaController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    await _preferences.init();
    if (mounted) {
      setState(() {
        if (_preferences.user.isNotEmpty) {
          _usernameController.text = _preferences.user;
          _rememberMe = true;
        }
      });
    }

    if (_empresaController.text.isEmpty) {
      final savedTenant = await _tenantStorage.load();
      if (savedTenant != null && mounted) {
        setState(() {
          _empresaController.text = savedTenant.slug;
        });
      }
    }
  }

  Future<void> _login() async {
    if (!hasConnection(context)) return;
    final slug = _empresaController.text.trim().toLowerCase();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (slug.isEmpty || username.isEmpty || password.isEmpty) {
      MessengerService.info('Completa todos los campos.');
      return;
    }
    final authService = Provider.of<AuthService>(context, listen: false);
    final navigator = Navigator.of(context);
    setState(() {
      _state = _LoginState.loading;
      _errorMessage = null;
    });

    _preferences.user = _rememberMe ? username : '';
    final result = await authService.login(slug, username, password); // login combinado
    if (!mounted) return;

    switch (result.status) {
      case AuthStatus.success:
        navigator.pushReplacementNamed(AppRoutes.home);
      case AuthStatus.mfaRequired:
        navigator.pushReplacementNamed(
          AppRoutes.mfa,
          arguments: {'username': username, 'password': password, 'challengeId': result.sessionChallenge ?? ''},
        );
      case AuthStatus.mfaSetupRequired:
        navigator.pushReplacementNamed(
          AppRoutes.mfaSetup,
          arguments: {
            'username': username,
            'password': password,
            'setupId': result.sessionChallenge ?? '',
            'secretCode': result.mfaSecretCode,
            'qrCodeUrl': result.mfaQrCodeUrl,
          },
        );
      case AuthStatus.failure:
        setState(() {
          _state = (result.statusCode == 403 || result.errorCode == 'TENANT_SUSPENDED')
              ? _LoginState.blocked
              : _LoginState.error;
          _errorMessage = result.errorMessage;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isLoading = _state == _LoginState.loading;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Center(
                  child: Image.asset('assets/images/logo.png', height: 120, width: 120, color: colorScheme.primary),
                ),

                // Campo 1 — Dominio (pre-llenado con slug persistido)
                TextField(
                  controller: _empresaController,
                  enabled: !isLoading,
                  decoration: const InputDecoration(labelText: 'Dominio', prefixIcon: Icon(Icons.business)),
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                ),

                // Campo 2 — Usuario
                TextField(
                  controller: _usernameController,
                  enabled: !isLoading,
                  decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person)),
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                ),

                // Campo 3 — Contraseña
                TextField(
                  controller: _passwordController,
                  enabled: !isLoading,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _login(),
                ),

                InkWell(
                  onTap: isLoading ? null : () => setState(() => _rememberMe = !_rememberMe),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: isLoading ? null : (v) => setState(() => _rememberMe = v ?? false),
                      ),
                      const Text('Recordar usuario'),
                    ],
                  ),
                ),
                if ((_state == _LoginState.error || _state == _LoginState.blocked) && _errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.error),
                    textAlign: TextAlign.center,
                  ),

                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton(onPressed: _login, child: const Text('Iniciar Sesión')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
