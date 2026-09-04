import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/services/s3_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
// import 'package:gaso_tenant_app/core/widgets/media/photo_picker.dart';
import 'package:gaso_tenant_app/features/profile/presentation/widgets/profile_photo.dart';
import 'package:gaso_tenant_app/features/profile/data/profile_service.dart';

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

  String fotoPerfilUrl = '';
  String fotoPerfil = '';
  String password = 'hardcoded';

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
    final filePath = 'Qa/slug/employees/${_sessionUser.user.id}/$fileName';
    try {
      String? newImageUrl = await _s3Service.uploadFileToS3(pickedFilePhoto, filePath, contentType);
      if (newImageUrl != null) {
        Map<String, dynamic> formData = { 'fotoPerfil': filePath };
        final response = await _profileService.updateProfilePhoto(formData);
        if (response.success) {
          if (fotoPerfil.isNotEmpty) {
            // borrar la foto anterior
            await _s3Service.deleteFromS3(fotoPerfil);
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

  // ignore: unused_element
  Future<void> _editUserName() async {
    final newUserName = await _showUserNameDialog(context: context, userName: _sessionUser.user.user);
    if (newUserName != null && newUserName != _sessionUser.user.user) {
      Map<String, dynamic> formData = {'user': newUserName};
      final response = await _profileService.updateUserName(formData);
      if (response.success) {
        _preferences.setString('Usuario', newUserName);
        MessengerService.info('Nombre de usuario actualizado');
      } else {
        MessengerService.info(response.message);
      }
    } else if (newUserName != null) {
      MessengerService.info('No se hicieron cambios');
    }
  }

  // ignore: unused_element
  Future<void> _editPassword() async {
    final newPassword = await _showPasswordDialog(context, password: password);
    if (newPassword != null && newPassword != password) {
      Map<String, dynamic> formData = {'password': newPassword};
      final response = await _profileService.updatePassword(formData);
      if (response.success) {
        if (mounted) setState(() => password = newPassword);
        _preferences.setString('Password', newPassword);
        MessengerService.info('Contraseña actualizada');
      } else {
        MessengerService.info(response.message);
      }
    } else if (newPassword != null) {
      MessengerService.info('No se hicieron cambios');
    }
  }

  Future<String?> _showUserNameDialog({required BuildContext context, String? userName}) {
    final formKey = GlobalKey<FormState>();
    final userNameController = TextEditingController(text: userName ?? '');
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nombre de usuario'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  TextFormField(
                    controller: userNameController,
                    inputFormatters: [LengthLimitingTextInputFormatter(25)],
                    decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El Nombre de usuario es requerido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, userNameController.text.trim());
                }
              },
              child: const Text('Modificar'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showPasswordDialog(BuildContext context, {required String password}) {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Contraseña'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      TextFormField(
                        controller: passwordController,
                        obscureText: !showCurrentPassword,
                        inputFormatters: [LengthLimitingTextInputFormatter(25)],
                        decoration: InputDecoration(
                          labelText: 'Contraseña actual',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(showCurrentPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              if (context.mounted) {
                                setState(() => showCurrentPassword = !showCurrentPassword);
                              }
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La Contraseña actual es requerida';
                          } else if (value != password) {
                            return 'No es tu contraseña actual';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: !showNewPassword,
                        inputFormatters: [LengthLimitingTextInputFormatter(10)],
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(showNewPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              setState(() => showNewPassword = !showNewPassword);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La Nueva contraseña es requerida';
                          } else if (value.length < 8) {
                            return 'Debe tener de 8 a 10 caracteres';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !showConfirmPassword,
                        inputFormatters: [LengthLimitingTextInputFormatter(10)],
                        decoration: InputDecoration(
                          labelText: 'Confirma tu contraseña',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              setState(() => showConfirmPassword = !showConfirmPassword);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La Confirmación es requerida';
                          } else if (value != newPasswordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context, newPasswordController.text);
                    }
                  },
                  child: const Text('Modificar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    final sections = [
      Row(
        spacing: 16,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sessionUser.user.name, style: textTheme.titleMedium),
                Text(
                  '${_sessionUser.user.positionName} - ${_sessionUser.user.departmentName}',
                  style: TextStyle(color: colorScheme.primary),
                ),
                Text(
                  '${_sessionUser.user.areaName} - Región ${_sessionUser.user.region}',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ],
            ),
          ),
          ProfilePhoto(imageUrl: fotoPerfilUrl, onTap: _onPickPhoto),
        ],
      ),
      Column(
        spacing: 16,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SectionTitle('Accesos'),
          InfoRow(_sessionUser.user.user, icon: Icons.person, label: 'Usuario', onAction: () {
            MessengerService.info('En proceso');
          }),
          InfoRow('********', icon: Icons.key, label: 'Contraseña', onAction: () {
            MessengerService.info('En proceso');
          }),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBarHeader(_sessionUser.user.positionName ?? 'Perfil', showNotifications: true),
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
