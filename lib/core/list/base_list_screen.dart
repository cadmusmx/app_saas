import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:gaso_tenant_app/core/widgets/lists/skeleton.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:provider/provider.dart';

/// Clase abstracta base que implementa el patrón Template Method
/// para manejar la lógica común de listas con paginación
abstract class BaseListScreen<T extends StatefulWidget, O> extends State<T> {
  late final SessionUser sessionUser;
  List<O> registros = [];
  final ScrollController scrollController = ScrollController();
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  int currentPage = 1;
  int get limit => 20;
  String get screenTitle;
  String get emptyMessage => 'No hay registros.';
  bool get hasFloatingActionButton => false;
  String? get floatingActionRoute => null;
  IconData get floatingActionIcon => Icons.add;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _init().then((ok) async {
      if (ok) {
        await onInitSuccess();
        await loadRegistros();
        if (registros.isEmpty && shouldClearFiltersOnEmpty) {
          clearFilters();
          await loadRegistros();
        }
        scrollController.addListener(_onScroll);
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    onDispose();
    super.dispose();
  }

  Future<List<O>> fetchData();
  Widget buildListItem(BuildContext context, O item, int index);

  void showFilters() => DebugLog.warning('showFilters no implementado');

  void clearFilters() => DebugLog.warning('clearFilters no implementado');

  Future<void> onInitSuccess() async {}
  void onDispose() {}
  bool get shouldClearFiltersOnEmpty => false;

  List<Widget>? buildAppBarActions() {
    return [IconButton(tooltip: 'Filtrar', onPressed: showFilters, icon: const Icon(Icons.filter_list))];
  }

  Future<bool> _init() async {
    final authContext = context.watch<AuthContext>();
    if (authContext.current != null && authContext.current?.user.id != null) {
      sessionUser = authContext.current!;
      return true;
    }
    MessengerService.info('Ocurrió un error al obtener sus datos');
    return false;
  }

  void _onScroll() {
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent) {
      if (!isLoadingMore && hasMore) {
        loadMoreRegistros();
      }
    }
  }

  Future<void> loadRegistros() async {
    if (isLoading) return;
    if (hasConnection(context)) {
      if (mounted) {
        setState(() {
          isLoading = true;
          currentPage = 1;
          hasMore = true;
        });
      }
      try {
        final list = await fetchData();
        if (mounted) {
          setState(() {
            registros = list.isNotEmpty ? [...list] : [];
            hasMore = list.length == limit;
          });
        }
      } catch (e) {
        DebugLog.error('Error loadRegistros: $e');
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  Future<void> loadMoreRegistros() async {
    if (isLoadingMore || !hasMore) return;
    if (mounted) setState(() => isLoadingMore = true);
    try {
      currentPage++;
      final list = await fetchData();
      if (list.isNotEmpty) {
        if (mounted) {
          setState(() {
            registros.addAll(list);
            hasMore = list.length == limit;
          });
        }
        if (!hasMore) MessengerService.info('No hay más registros');
      }
    } catch (e) {
      currentPage--;
      DebugLog.error('Error loadMoreRegistros: $e');
    } finally {
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  Widget buildListView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MasonryGridView.count(
          crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
          crossAxisSpacing: 8,
          controller: scrollController,
          itemCount: registros.length + (isLoadingMore ? 1 : 0),
          padding: buildListPadding(constraints),
          itemBuilder: (context, index) {
            if (index == registros.length) {
              return const Center(
                child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
              );
            }
            return buildListItem(context, registros[index], index);
          },
        );
      },
    );
  }

  EdgeInsets buildListPadding(BoxConstraints constraints) {
    return EdgeInsets.only(
      left: ResponsiveHelper.mainPadding(constraints),
      right: ResponsiveHelper.mainPadding(constraints),
      top: 16,
      bottom: 64,
    );
  }

  Widget buildBody(BuildContext context) {
    if (isLoading) return const SkeletonList();
    if (registros.isEmpty) return Center(child: Text(emptyMessage));
    return RefreshIndicator(onRefresh: loadRegistros, child: buildListView());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarHeader(screenTitle, actions: buildAppBarActions()),
      body: buildBody(context),
      floatingActionButton: hasFloatingActionButton && floatingActionRoute != null
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, floatingActionRoute!),
              child: Icon(floatingActionIcon),
            )
          : null,
    );
  }
}
