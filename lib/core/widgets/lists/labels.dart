import 'package:flutter/material.dart';

class LabelValue extends StatelessWidget {
  final String label;
  final dynamic value;

  const LabelValue(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final ColorScheme colorScheme = ColorScheme.of(context);
    final validValue = value != null && value.toString().isNotEmpty;
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 8,
      children: [
        Text(
          '$label: ',
          style: textStyle!.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          validValue ? value.toString() : 'Sin registro',
          style: validValue ? textStyle : textStyle.copyWith(color: colorScheme.outline),
        ),
      ],
    );
  }
}

class RowLV extends StatelessWidget {
  final String label;
  final String value;
  final MainAxisAlignment alignment;

  const RowLV(this.label, this.value, {this.alignment = MainAxisAlignment.start, super.key});

  const RowLV.between(String label, String value, {Key? key})
      : this(label, value, alignment: MainAxisAlignment.spaceBetween, key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      mainAxisAlignment: alignment,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// Títulos
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionTitle(this.title, {this.subtitle, super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme .of(context);
    final colorScheme = ColorScheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleLarge),
          if (subtitle != null) Text(subtitle!, style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline))
        ],
      ),
    );
  }
}
