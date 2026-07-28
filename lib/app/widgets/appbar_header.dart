import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/features/notifications/data/notification_service.dart';
import 'package:gaso_tenant_app/features/notifications/presentation/notifications_screen.dart';

class AppBarHeader extends StatefulWidget implements PreferredSizeWidget {
  final bool showNotifications;
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const AppBarHeader(this.title, {super.key, this.showNotifications = false, this.actions, this.leading});

  @override
  State<AppBarHeader> createState() => _AppBarHeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppBarHeaderState extends State<AppBarHeader> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    return AppBar(
      leadingWidth: 32,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      titleTextStyle: textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary),
      leading: widget.leading,
      title: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(widget.title.toUpperCase(), overflow: TextOverflow.ellipsis, maxLines: 1)),
          if (widget.showNotifications)
            ValueListenableBuilder<int>(
              valueListenable: _notificationService.notificationCount,
              builder: (context, count, child) {
                return IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute<void>(builder: (context) => NotificationsScreen()));
                  },
                  icon: Badge.count(count: count, isLabelVisible: count > 0, child: Icon(Icons.notifications)),
                );
              },
            ),
        ],
      ),
      titleSpacing: 8.0,
      actions: widget.actions,
    );
  }
}
