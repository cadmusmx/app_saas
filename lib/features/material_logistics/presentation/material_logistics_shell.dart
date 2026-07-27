import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/material_logistics.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/material_logistics_holder.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/header_form.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/sites_screen.dart';

/// Provee el [MaterialLogisticsHolder] con alcance de ruta
/// (`create:` → `dispose()` automático al hacer pop),
/// aloja las dos vistas tope en un `IndexedStack`.
/// El sub-form de un sitio se abre como push sobre el
/// Navigator con `ChangeNotifierProvider.value`, conservando el mismo holder.
class MaterialLogisticsShell extends StatelessWidget {
  const MaterialLogisticsShell({super.key, this.record});

  /// Registro a editar; null en creación. Siembra el holder.
  final MaterialLogistics? record;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MaterialLogisticsHolder(record: record),
      child: const _MaterialLogisticsView(),
    );
  }
}

class _MaterialLogisticsView extends StatelessWidget {
  const _MaterialLogisticsView();

  @override
  Widget build(BuildContext context) {
    final holder = context.watch<MaterialLogisticsHolder>();
    final onSitios = holder.view == LogisticsView.sitios;
    final isEdition = holder.isEdition;
    // Raíz por modo: creación = Cabecera, edición = Sitios.
    // El back se intercepta solo fuera de la raíz para volver a ella; en la raíz, sale de la ruta.
    final atRoot = isEdition ? onSitios : !onSitios;

    return PopScope(
      canPop: atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final h = context.read<MaterialLogisticsHolder>();
        isEdition ? h.goToSitios() : h.backToCabecera();
      },
      child: IndexedStack(
        index: holder.view.index,
        children: const [
          HeaderForm(),
          SitesScreen(),
        ],
      ),
    );
  }
}
