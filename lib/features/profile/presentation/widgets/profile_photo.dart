import 'package:flutter/material.dart';

class ProfilePhoto extends StatelessWidget {
  final String imageUrl;
  final void Function()? onTap;
  const ProfilePhoto({super.key, required this.imageUrl, this.onTap});

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      fullscreenDialog: true,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 24),
        constraints: const BoxConstraints(minWidth: double.infinity),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('Foto de perfil', overflow: TextOverflow.ellipsis)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        content: _buildImage(),
      ),
    );
  }

  Widget _buildImage([double? size]) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Icon(Icons.person, size: 40, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showFullImage(context),
      customBorder: const CircleBorder(),
      child: CircleAvatar(
        radius: 40,
        backgroundColor: colorScheme.surfaceContainerLow,
        child: ClipOval(child: _buildImage(80)),
      ),
    );
  }
}
