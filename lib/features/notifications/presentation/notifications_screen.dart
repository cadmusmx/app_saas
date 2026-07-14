import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/features/notifications/data/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final ScrollController scrollController = ScrollController();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getNotifications().then((_) => setState(() => _isLoading = false));
  }

  Future<void> _getNotifications() async {
    final notifications = await _notificationService.getNotifications();
    setState(() => _notifications = notifications);
  }

  Future<void> _deleteNotification(int index) async {
    await _notificationService.deleteNotification(index);
    await _getNotifications();
  }

  Future<void> _clearAllNotifications() async {
    if (_notifications.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todas'),
        content: Text('¿Estás seguro de que deseas eliminar las ${_notifications.length} notificaciones?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar todas')),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationService.clearAllNotifications();
      await _getNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBarHeader(
        'Notificaciones',
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Borrar todas',
              onPressed: _clearAllNotifications,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        'No hay notificaciones',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return MasonryGridView.count(
                      crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      controller: scrollController,
                      itemCount: _notifications.length,
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.mainPadding(constraints),
                        vertical: 16,
                      ),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final String body = notification['body'] ?? '';
                        final List<String> links = getLinks(body);
                        return _NotificationCard(
                          title: notification['title'] ?? 'Gaso ERP',
                          body: links.isEmpty ? body : getText(body),
                          links: links,
                          timestamp: notification['timestamp'] ?? '',
                          onDelete: () => _deleteNotification(index),
                        );
                      },
                    );
                  },
                ),
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final String timestamp;
  final VoidCallback onDelete;
  final List<String> links;
  const _NotificationCard({
    required this.title,
    required this.body,
    required this.timestamp,
    required this.onDelete,
    this.links = const [],
  });

  Future<void> _abrirEnlace(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            if (body.isNotEmpty)
              SelectableText(body, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            for (final url in links) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _abrirEnlace(url),
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
            SizedBox(height: 8),
            if (DateTime.tryParse(timestamp) != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.parse(timestamp)),
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
