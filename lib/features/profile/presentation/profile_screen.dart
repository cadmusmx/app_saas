import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/widgets/lists/tiles.dart';
// import 'package:gaso_tenant_app/core/widgets/media/photo_picker.dart';
import 'package:gaso_tenant_app/core/services/s3_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/features/profile/presentation/widgets/profile_photo.dart';
// import 'package:gaso_tenant_app/features/profile/presentation/account_screen.dart';
// import 'package:gaso_tenant_app/features/profile/presentation/personal_screen.dart';
import 'package:gaso_tenant_app/features/profile/data/profile_service.dart';
import 'package:gaso_tenant_app/features/profile/domain/profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final S3Service _s3Service = S3Service();
  // final PhotoPicker _photoPicker = PhotoPicker();
  late final ProfileService _profileService = ProfileService();
  late final SharedPreferences _preferences;
  late final SessionUser _sessionUser;
  bool _sessionReady = false;

  String imageUrl = '';
  String fotoDigital = '';

  @override
  void initState() {
    super.initState();
    final session = AuthContext.instance.current;
    if (session != null && session.user.id != null) {
      _sessionUser = session;
      _sessionReady = true;
      SharedPreferences.getInstance().then((preferences) => {_preferences = preferences});
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MessengerService.info('Ocurrió un error al obtener sus datos');
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    }
  }

  Future<void> _onPickPhoto() async {
    return MessengerService.info('No disponible');
    /* try {
      final picked = await _photoPicker.pickPhoto(context);
      if (picked != null) {
        File file = File(picked.path);
        await _editProfilePhoto(file);
      }
    } catch (e) {
      DebugLog.warning('_onPickPhoto: $e');
      MessengerService.error('No se pudo acceder al recurso');
    } */
  }

  // ignore: unused_element
  Future<void> _editProfilePhoto(File pickedFilePhoto) async {
    if (!hasConnection(context)) return;
    final fileExtension = p.extension(pickedFilePhoto.path);
    final String fileName = 'foto-digital-${getCurrentFormattedDate('yyyyMMdd:hhmmss')}$fileExtension';
    final contentType = fileExtension.contains('png') ? 'image/png' : 'image/jpeg';
    final filePath = 'profiles/${_sessionUser.user.id}/${EDocumentTypes.fotoDigital.name}/$fileName';
    try {
      String? newImageUrl = await _s3Service.uploadFileToS3(pickedFilePhoto, filePath, contentType);
      if (newImageUrl != null) {
        Map<String, dynamic> formData = {
          EUserDataUpdate.idusuario.name: _sessionUser.user.id,
          EDocumentTypes.fotoDigital.name: filePath,
        };
        final response = await _profileService.addFiles(formData);
        if (response.success) {
          if (fotoDigital.isNotEmpty) {
            // borrar la foto anterior
            await _s3Service.deleteFromS3(fotoDigital);
          }
          await _preferences.setString('FotoDigital', filePath);
          MessengerService.info('La imagen ha sido cambiada');
          return;
        }
        MessengerService.info(response.message);
      } else {
        MessengerService.error('Hubo un error al guardar la imagen');
      }
    } catch (e) {
      DebugLog.warning('_editProfilePhoto: $e');
      MessengerService.error('No se pudo completar la edición. Intente más tarde.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    final List<Flex> sections = [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 16,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sessionUser.user.name, style: textTheme.titleMedium),
                Text(
                  '${_sessionUser.profile.name} ${_sessionUser.user.department}',
                  style: TextStyle(color: colorScheme.primary),
                ),
                Text(
                  '${_sessionUser.user.area} ${_sessionUser.user.region}',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ],
            ),
          ),
          ProfilePhoto(imageUrl: imageUrl, onTap: _onPickPhoto),
        ],
      ),
      Column(
        children: [
          NavigationListTile('Tu cuenta', subtitle: 'Datos que representan a la cuenta', Icons.person, () {
            return MessengerService.info('No disponible');
            /* Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) =>
                    AccountScreen(idUser: _sessionUser.user.id, user: 'HARDCODED-user', password: 'HARDCODED-password'),
              ),
            ); */
          }),
          NavigationListTile(
            'Información personal',
            subtitle: 'Identificación, datos generales, contactos',
            Icons.badge,
            () {
              return MessengerService.info('No disponible');
              /* Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (context) => PersonalScreen(idUser: _sessionUser.user.id)),
              ); */
            },
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBarHeader(_sessionUser.profile.name, showNotifications: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
              child: MasonryGridView.count(
                crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sections.length,
                itemBuilder: (context, index) => sections[index],
              ),
            ),
          );
        },
      ),
    );
  }
}
