/// Cache en memoria del token de sesión.
/// Permite que HttpService lea el token sin importar AuthService,
/// evitando una dependencia circular entre ambas capas.
class AuthToken {
  AuthToken._();
  static String? _value;
  static String? get value => _value;
  static void set(String token) => _value = token;
  static void clear() => _value = null;
}
