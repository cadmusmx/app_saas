import 'dart:typed_data';
import 'package:signature/signature.dart';
import 'package:flutter/material.dart';
import 'package:gaso_tenant_app/core/widgets/media/visual_dialogs.dart';

class SignatureCard extends StatefulWidget {
  final String title;
  final SignatureController controller;
  final double height;
  final Uint8List? existingSignature;
  final void Function()? onRemake;

  const SignatureCard(this.title, this.controller,
      {this.height = 120, this.existingSignature, this.onRemake, super.key});

  @override
  State<SignatureCard> createState() => _SignatureCardState();
}

class _SignatureCardState extends State<SignatureCard> {
  bool get thereIsASignature => widget.controller.isNotEmpty || widget.existingSignature != null;

  void _showSign(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.all(16),
        constraints: BoxConstraints(minWidth: double.infinity),
        backgroundColor: Colors.white,
        title: Text(widget.title),
        content: Image.memory(bytes, scale: 0.5),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canView = thereIsASignature;
    widget.controller.onDrawEnd = () => setState(() => canView = thereIsASignature);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(widget.title),
        Container(
          height: widget.height,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.existingSignature != null
                ? Stack(children: [imageFromBytes(widget.existingSignature!)])
                : Signature(controller: widget.controller, backgroundColor: Colors.white),
          ),
        ),
        Row(
          children: [
            if (widget.existingSignature != null)
              Flexible(child: TextButton(onPressed: widget.onRemake, child: const Text('Rehacer')))
            else ...[
              Flexible(
                child: TextButton(
                    onPressed: () {
                      widget.controller.clear();
                      if (mounted) {
                        setState(() {
                          canView = false;
                          widget.controller.disabled = false;
                        });
                      }
                    },
                    child: const Text('Limpiar')),
              ),
              Flexible(
                child: TextButton(
                  onPressed: () => setState(() => widget.controller.disabled = !widget.controller.disabled),
                  child: Text(widget.controller.disabled ? 'Desbloquear' : 'Bloquear'),
                ),
              ),
            ],
            if (canView)
              Flexible(
                child: TextButton(
                  onPressed: () async {
                    final bytes = widget.existingSignature ?? await widget.controller.toPngBytes();
                    if (bytes != null) _showSign(bytes);
                  },
                  child: const Text('Ver'),
                ),
              ),
          ],
        )
      ],
    );
  }
}
