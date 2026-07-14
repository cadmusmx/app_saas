/// RBAC · Máscara de permisos CRUD (bitmask).
/// FUENTE ÚNICA del orden de bits:
///  se define en el BFF y aquí se REPLICA sin reordenar.
///  Reordenar estos bits rompe toda máscara ya almacenada en BD y de-sincroniza a Flutter del resolver / guards / /api/me.
///   R = 1  (Read   / ver)
///   W = 2  (Write  / crear)
///   U = 4  (Update / editar)
///   D = 8  (Delete / eliminar)
/// Invariante de canonicidad: (W | U | D) ⇒ R.
/// No puedes crear/editar/eliminar algo que no puedes ver.
/// 9 máscaras válidas de 16: {0,1,3,5,7,9,11,13,15} (espejo del CHECK en Security.UserViews).
class Perm {
  Perm._();
 
  static const int r = 1; // ver
  static const int w = 2; // crear
  static const int u = 4; // editar
  static const int d = 8; // eliminar
 
  static const int none = 0;
  static const int all = r | w | u | d; // 15
 
  /// Espejo EXACTO del CHECK de Security.UserViews.
  static const List<int> canonicalMasks = [0, 1, 3, 5, 7, 9, 11, 13, 15];
 
  static bool hasRead(int mask) => (mask & r) == r;
  static bool hasWrite(int mask) => (mask & w) == w;
  static bool hasUpdate(int mask) => (mask & u) == u;
  static bool hasDelete(int mask) => (mask & d) == d;
 
  /// Entero en 0..15 y, si tiene W/U/D, también R.
  /// Uso: saneo fail-closed en me_service al mapear /api/me →
  ///   final safe = Perm.isCanonical(m) ? m : Perm.none;
  /// (toda no-canónica carece de R, así que forzar a 0 no recorta nada legítimo).
  static bool isCanonical(int mask) {
    if (mask < 0 || mask > all) return false;
    const wud = w | u | d;
    if ((mask & wud) != 0 && (mask & r) == 0) return false;
    return true;
  }
 
  /// Intersección (el resolver server-side hace userMask & deptCeiling).
  /// En cliente casi no se usa, pero se incluye por paridad con el contrato.
  static int intersect(int a, int b) => a & b;
 
  /// Representación legible para debug_log, p.ej. 7 -> "R|W|U", 0 -> "-".
  static String describe(int mask) {
    if (mask == none) return '-';
    final parts = <String>[];
    if (hasRead(mask)) parts.add('R');
    if (hasWrite(mask)) parts.add('W');
    if (hasUpdate(mask)) parts.add('U');
    if (hasDelete(mask)) parts.add('D');
    return parts.join('|');
  }
}