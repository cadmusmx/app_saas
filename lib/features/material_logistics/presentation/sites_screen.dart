import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/storage/preferences.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/sitio_draft.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/material_logistics_holder.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/sites_form.dart';

/// Vista de Sitios: resumen de cabecera a la vista + lista de sitios capturados.
/// Cada sitio se edita en el sub-form sobre una `copy()`; el alta usa un `SitioDraft.nuevo()`.
/// La Confirmación + el Submit llegan en R3b.
class SitesScreen extends StatefulWidget {
  const SitesScreen({super.key});

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  late final MaterialLogisticsHolder _holder;
  late final SessionUser _sessionUser;
  final Preferences _preferences = Preferences();
  bool _isSubmitting = false;
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    _holder = context.read<MaterialLogisticsHolder>();
    final session = AuthContext.instance.current;
    if (session != null && session.user.id != null) {
      _sessionUser = session; // Podríamos pasarlo como parámetro desde header
      _sessionReady = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MessengerService.info('Ocurrió un error al obtener sus datos');
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    }
  }

  /// Abre el sub-form como push sobre el Navigator, conservando el mismo holder.
  void _openSitio({required SitioDraft draft, int? index}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: _holder,
          child: SitesForm(draft: draft, index: index),
        ),
      ),
    );
  }

  Future<void> _confirmarBorrar(int index) async {
    final s = _holder.sitios[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sitio'),
        content: Text('¿Eliminar el sitio ${s.idSitio}-${s.nombreSitio}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ELIMINAR')),
        ],
      ),
    );
    if (ok == true) _holder.removeSitio(index);
  }

  Widget _resumenCabecera(MaterialLogisticsHolder holder) {
    final responsable = holder.nombreResponsable ?? (holder.original?.responsable ?? '');
    final fecha = holder.fecha != null ? getFormattedDate(holder.fecha!, 'dd/MM/yyyy') : '—';
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 4,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Datos generales', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: holder.backToCabecera,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('EDITAR'),
                  ),
                ],
              ),
              Text('Fecha: $fecha'),
              if (responsable.isNotEmpty) Text('Responsable: $responsable'),
              Text('Unidad: ${holder.unidadPlaca}'),
              Text('Operador: ${holder.nombreOperador}'),
              Text(
                'Horario: ${holder.horaLlegada ?? '—'} · ${holder.horaInicioDescarga ?? '—'} · '
                '${holder.horaSalida ?? '—'}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sitioCard(int index) {
    final s = _holder.sitios[index];
    return Card(
      child: ListTile(
        title: Text('${s.idSitio}-${s.nombreSitio}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${s.tipos.length} tipo(s) · ${s.evidencias.length} evidencia(s)'),
        onTap: () => _openSitio(draft: _holder.getSitio(index)!.copy(), index: index),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _openSitio(draft: _holder.getSitio(index)!.copy(), index: index),
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmarBorrar(index)),
          ],
        ),
      ),
    );
  }

  // 3) Método de envío
  Future<void> _submit() async {
    if (_holder.sitios.isEmpty) {
      return MessengerService.info('Agrega al menos un sitio.');
    }
    if (!_holder.confirmado) {
      return MessengerService.info('Confirma la información antes de enviar.');
    }
    setState(() => _isSubmitting = true);
    try {
      final idUser = _sessionUser.user.id ?? 0;
      final tenantSlug = _sessionUser.tenant.slug; // [ADD]
      if (idUser == 0) {
        return MessengerService.error('No se pudo obtener el usuario.');
      }
      final response = await _holder.submit(idUser, tenantSlug); // [UPD]
      if (!mounted) return;
      if (response.success) {
        if (!_holder.isEdition) {
          await _preferences.init(); // garantiza el SharedPreferences cargado
          _preferences.lmRE = _holder.re; // persiste el B-mínimo
        }
        MessengerService.info(response.message);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        MessengerService.info(response.message);
      }
    } catch (e) {
      DebugLog.error('Error submit logística: $e');
      MessengerService.error('Ocurrió un error al enviar.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final holder = context.watch<MaterialLogisticsHolder>();
    return Scaffold(
      appBar: AppBarHeader(
        '${holder.isEdition ? 'Edición de la' : 'Sitios de la'} ${holder.re ? 'recepción' : 'entrega'}',
        leading: holder.isEdition
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: holder.backToCabecera),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSitio(draft: SitioDraft.nuevo()),
        icon: const Icon(Icons.add),
        label: const Text('AGREGAR SITIO'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
              child: Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _resumenCabecera(holder),
                  SectionTitle('Sitios', subtitle: 'Validación de material, evidencia e incidencias'),
                  if (holder.sitios.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Aún no hay sitios registrados.')),
                    )
                  else
                    for (int i = 0; i < holder.sitios.length; i++) _sitioCard(i),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: holder.confirmado,
                    onChanged: (v) => holder.setConfirmado(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    isThreeLine: true,
                    title: Text('Confirme la información'),
                    subtitle: Text(
                      'Los datos y evidencia proporcionada corresponden a la ${holder.re ? 'recepción' : 'entrega'} real del material.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(holder.isEdition ? 'GUARDAR CAMBIOS' : 'ENVIAR'),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
