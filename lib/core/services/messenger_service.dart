import 'dart:async';
import 'package:flutter/material.dart';

/// Tipo visual del snack.
enum _NoticeType { info, success, error }

class MessengerService {
  static final GlobalKey<OverlayState> overlayKey = GlobalKey<OverlayState>();

  static OverlayEntry? _entry;

  static void info(String message, {int duration = 3}) {
    _show(
      message,
      type: _NoticeType.info,
      duration: Duration(seconds: duration),
    );
  }

  static void success(String message) {
    _show(message, type: _NoticeType.success, duration: const Duration(seconds: 3));
  }

  static void error(String message) {
    _show(message, type: _NoticeType.error, duration: const Duration(minutes: 5), showClose: true);
  }

  static void actionSnackBar(String message, VoidCallback onPressed, String actionLabel) {
    _show(
      message,
      type: _NoticeType.info,
      duration: const Duration(seconds: 4),
      actionLabel: actionLabel,
      onAction: onPressed,
    );
  }

  /// Descarta el aviso visible (si lo hay).
  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }

  static void _show(
    String message, {
    required _NoticeType type,
    required Duration duration,
    bool showClose = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = overlayKey.currentState;
    if (overlay == null) return;

    // Modelo de un solo aviso: el nuevo reemplaza al anterior.
    dismiss();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _NoticeHost(
        message: message,
        type: type,
        duration: duration,
        showClose: showClose,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () {
          if (_entry == entry) {
            entry.remove();
            _entry = null;
          }
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);
  }
}

class _NoticeHost extends StatefulWidget {
  final String message;
  final _NoticeType type;
  final Duration duration;
  final bool showClose;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _NoticeHost({
    required this.message,
    required this.type,
    required this.duration,
    required this.showClose,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  State<_NoticeHost> createState() => _NoticeHostState();
}

class _NoticeHostState extends State<_NoticeHost> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (mounted) {
      await _controller.reverse();
    }
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color get _bg {
    switch (widget.type) {
      case _NoticeType.success:
        return Colors.green.shade900;
      case _NoticeType.error:
        return Colors.red.shade900;
      case _NoticeType.info:
        return Colors.grey.shade900;
    }
  }

  bool get _bold => widget.type != _NoticeType.info;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SlideTransition(
            position: _slide,
            child: Dismissible(
              key: const ValueKey('messenger_notice'),
              direction: DismissDirection.down,
              onDismissed: (_) => widget.onDismiss(),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                color: _bg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (widget.actionLabel != null)
                        TextButton(
                          onPressed: () {
                            widget.onAction?.call();
                            _dismiss();
                          },
                          child: Text(
                            widget.actionLabel!,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (widget.showClose)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _dismiss,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
