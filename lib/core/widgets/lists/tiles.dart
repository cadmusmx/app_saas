import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/core/access/access_validator.dart';

class BaseListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final IconData trailingIcon;
  final void Function() onTap;

  const BaseListTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.trailingIcon,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Icon(trailingIcon),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      onTap: onTap,
    );
  }
}

class NavigationListTile extends BaseListTile {
  const NavigationListTile(String title, IconData icon, void Function() onTap, {super.subtitle, super.key})
    : super(title: title, icon: icon, trailingIcon: Icons.chevron_right, onTap: onTap);
}

class ActionListTile extends BaseListTile {
  const ActionListTile(
    String title,
    String subtitle,
    IconData icon,
    IconData actionIcon,
    void Function() onTap, {
    super.key,
  }) : super(title: title, subtitle: subtitle, icon: icon, trailingIcon: actionIcon, onTap: onTap);
}

class TwoActionListTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData lIcon;
  final bool lHasState;
  final IconData lSelectedIcon;
  final IconData tIcon;
  final void Function() onLeading;
  final void Function() onTrailing;

  const TwoActionListTile(
    this.title,
    this.subtitle,
    this.tIcon,
    this.onLeading,
    this.onTrailing, {
    this.lIcon = Icons.keyboard_arrow_down,
    this.lHasState = true,
    this.lSelectedIcon = Icons.keyboard_arrow_up,
    super.key,
  });

  @override
  State<TwoActionListTile> createState() => _TwoActionListTileState();
}

class _TwoActionListTileState extends State<TwoActionListTile> {
  bool _leadingSelected = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: InkWell(
        onTap: () {
          widget.onLeading();
          if (widget.lHasState && mounted) setState(() => _leadingSelected = !_leadingSelected);
        },
        child: Icon(_leadingSelected ? widget.lSelectedIcon : widget.lIcon),
      ),
      title: Text(widget.title),
      trailing: InkWell(onTap: widget.onTrailing, child: Icon(widget.tIcon)),
      subtitle: Text(widget.subtitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }
}

class ExpansionListTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final void Function() onAdd;
  final List<Widget> children;

  const ExpansionListTile(this.title, this.subtitle, this.onAdd, {super.key, this.children = const <Widget>[]});

  @override
  State<ExpansionListTile> createState() => _ExpansionListTileState();
}

class _ExpansionListTileState extends State<ExpansionListTile> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(widget.title, style: textTheme.titleMedium),
          subtitle: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.subtitle, style: textTheme.bodyMedium),
                Text(
                  '${widget.children.length} registro${widget.children.length == 1 ? '' : 's'}',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(onPressed: widget.onAdd, icon: Icon(Icons.add)),
              if (widget.children.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _selected = !_selected),
                  icon: Icon(_selected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        ),
        if (_selected) ...widget.children,
      ],
    );
  }
}

class DrawerOption {
  String? path;
  String title;
  IconData icon;
  bool released;
  DrawerOption({this.path, required this.title, required this.icon, this.released = true});
}

class DrawerOptionAV extends AccessValidator {
  final DrawerOption option;
  DrawerOptionAV(this.option, {List<List<String>> config = AccessConfig.all, bool strict = false})
    : super(config, strict);
}

class DrawerListTile extends StatelessWidget {
  final DrawerOption opt;
  final Color color;
  const DrawerListTile(this.opt, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    return ListTile(
      leading: Icon(opt.icon, color: opt.released ? color : Colors.grey),
      title: Text(
        opt.title.toUpperCase(),
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium?.copyWith(color: opt.released ? null : Colors.grey),
      ),
      onTap: (opt.released && opt.path != null) ? () => Navigator.pushNamed(context, opt.path!) : null,
    );
  }
}
