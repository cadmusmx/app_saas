import 'dart:convert';
import 'dart:io';

import 'package:gaso_tenant_app/core/http/api_exception.dart';
import 'package:gaso_tenant_app/core/http/http_service.dart';
import 'package:gaso_tenant_app/core/http/service_response.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/tenant/tenant_context.dart';
import 'package:gaso_tenant_app/features/material_validation/domain/material_catalogs.dart';

/// Servicio stateless de catálogos:
/// 1 sola llamada a `GET warehouses/material-validation/catalogs` (bit R).
class MaterialCatalogsService extends HttpService {
  static const String _endpoint = 'warehouses/material-validation/catalogs';

  Future<ServiceResponse<MaterialCatalogs>> getCatalogs() async {
    try {
      final res = await send('GET', _endpoint);
      final body = jsonDecode(res.body);
      if (body is! Map) {
        return ServiceResponse.error('Formato inesperado al obtener los catálogos.', statusCode: res.statusCode);
      }
      return ServiceResponse.ok(MaterialCatalogs.fromJson(body.cast<String, dynamic>()), statusCode: res.statusCode);
    } on ApiException catch (e) {
      return ServiceResponse.error(
        e.message.isNotEmpty ? e.message : 'No se pudieron cargar los catálogos.',
        statusCode: e.statusCode,
      );
    } on SocketException {
      return ServiceResponse.error('Sin conexión con el servidor.');
    } on FormatException {
      return ServiceResponse.error('No se pudo interpretar la respuesta del servidor.');
    } catch (e) {
      DebugLog.error('getCatalogs $e');
      return ServiceResponse.error('Error inesperado al cargar los catálogos.');
    }
  }
}

/// Caché **in-memory, tenant-scoped** de los catálogos.
/// Objetivo: acortar el tiempo de carga del formulario evitando re-pedir los catálogos en cada
/// apertura dentro de la misma sesión.
///
/// Es un singleton para sobrevivir entre widgets (cada form es efímero).
/// No usa SharedPreferences, lo que además elimina de raíz la fuga entre tenants del `CachedSelectionList` legacy:
///  - la key implícita es el `slug` de `TenantContext`;
///     si cambia, se invalida y se vuelve a pedir (nunca sirve catálogos del tenant anterior);
///  - `ttl` acota la vejez dentro del mismo tenant;
///  - `_inflight` deduplica llamadas concurrentes (p. ej. form + lista a la vez).
///
/// Uso desde el form: `_catalogs = await MaterialCatalogsCache.instance.load();`
/// y construir los dropdowns desde `_catalogs` (sin el race del constructor async ni el `Future.delayed(2s)` legacy).
/// Invalidar en logout es opcional (el auto-invalidado por slug ya cubre el cambio de empresa).
class MaterialCatalogsCache {
  MaterialCatalogsCache._();
  static final MaterialCatalogsCache instance = MaterialCatalogsCache._();

  final MaterialCatalogsService _service = MaterialCatalogsService();

  /// Vejez máxima aceptable dentro del mismo tenant.
  static const Duration ttl = Duration(minutes: 30);

  MaterialCatalogs? _catalogs;
  String? _slug;
  DateTime? _loadedAt;
  Future<MaterialCatalogs>? _inflight;

  /// Acceso síncrono al último valor cargado (o `null` si aún no hay).
  /// Útil para builds posteriores al `await load()`.
  MaterialCatalogs? get current => _catalogs;

  bool get _isFresh =>
      _catalogs != null &&
      _slug == TenantContext.instance.slug &&
      _loadedAt != null &&
      DateTime.now().difference(_loadedAt!) < ttl;

  /// Devuelve los catálogos: sirve la caché si está fresca y es del tenant actual;
  /// si no, hace **una** petición (deduplicada).
  /// Lanza `Exception` con el mensaje del server si la carga falla
  /// (el caller muestra el error y deja los catálogos vacíos; el siguiente intento reintenta).
  Future<MaterialCatalogs> load({bool forceRefresh = false}) {
    final slug = TenantContext.instance.slug;
    if (slug != _slug) invalidate(); // cambio de tenant → nunca sirvas los del anterior
    if (!forceRefresh && _isFresh) return Future.value(_catalogs);
    return _inflight ??= _fetch(slug);
  }

  Future<MaterialCatalogs> _fetch(String? slug) async {
    try {
      final res = await _service.getCatalogs();
      if (!res.success || res.data == null) {
        throw Exception(res.message.isNotEmpty ? res.message : 'No se pudieron cargar los catálogos.');
      }
      _catalogs = res.data;
      _slug = slug;
      _loadedAt = DateTime.now();
      return _catalogs!;
    } finally {
      _inflight = null;
    }
  }

  /// Limpia la caché. Llamar en logout/cambio de tenant si se quiere forzar
  /// (opcional: `load()` ya se auto-invalida cuando cambia el slug).
  void invalidate() {
    _catalogs = null;
    _slug = null;
    _loadedAt = null;
    // `_inflight` no se toca: una carga en curso se resuelve y limpia sola.
  }
}
