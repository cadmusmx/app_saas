import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/forms/fields_control.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/features/profile/domain/profile.dart';
import 'package:gaso_tenant_app/features/profile/data/profile_service.dart';

class AccountScreen extends StatefulWidget {
  final int? idUser;
  final String user;
  final String password;
  const AccountScreen({super.key, required this.idUser, required this.user, required this.password});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final SharedPreferences _preferences;
  final ProfileService _usuarioService = ProfileService();

  bool editionMode = false;
  String user = '';
  String password = '';
  Map<String, FieldValueControl> fieldsVC = {};
  final Map<String, EditableField> editableFields = {
    'Email': EditableField(EUserDataUpdate.correo, type: FVCType.email),
    'NumCelular': EditableField(EUserDataUpdate.telefono, type: FVCType.number),
  };

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((preferences) => {_preferences = preferences, _fillFields()});
  }

  void _fillFields() {
    Map<String, FieldValueControl> fieldsFromEF = {};
    for (var field in editableFields.entries) {
      String value = _preferences.getString(field.key) ?? '';
      fieldsFromEF.addAll({
        field.key: FieldValueControl(
          value,
          field.key,
          TextEditingController(),
          field.value.type,
          requestInput: field.value.updateKey.name,
        )
      });
    }
    if (mounted) {
      setState(() {
        fieldsVC = fieldsFromEF;
        user = widget.user;
        password = widget.password;
      });
    }
    _setControllersInitialData();
  }

  Future<void> _setControllersInitialData() async {
    for (var field in editableFields.entries) {
      fieldsVC[field.key]!.setValueToControl();
    }
  }

  Future<void> _setSavedData(List<FieldValueControl> changedValues) async {
    for (var field in changedValues) {
      fieldsVC[field.spName]!.setControlToValue();
      await _preferences.setString(field.spName, fieldsVC[field.spName]!.value);
    }
  }

  Future<void> _edition() async {
    if (!editionMode) {
      if (mounted) setState(() => editionMode = true);
    } else if (_formKey.currentState!.validate()) {
      if (!hasConnection(context)) return;
      try {
        List<FieldValueControl> changedValues = [...fieldsVC.values.where((field) => field.changed)];
        if (changedValues.isNotEmpty) {
          Map<String, dynamic> formData = _buildPayload(changedValues);
          final response = await _usuarioService.updateUser(formData);
          if (response.success) {
            await _setSavedData(changedValues);
            MessengerService.info('Los datos han sido guardados');
          } else {
            MessengerService.info(response.message);
          }
        }
      } catch (e) {
        MessengerService.info('No se pudo completar la edición. Intente más tarde.');
      } finally {
        if (mounted) setState(() => editionMode = false);
      }
    } else {
      MessengerService.info('Corrige los campos marcados.');
    }
  }

  Map<String, dynamic> _buildPayload(List<FieldValueControl> fieldValues) {
    Map<String, dynamic> payload = {
      EUserDataUpdate.idusuario.name: widget.idUser,
    };
    for (var fieldValue in fieldValues) {
      payload.addAll(fieldValue.payload);
    }
    return payload;
  }

  Future<void> _editUserName() async {
    final newUserName = await _showUserNameDialog(context: context, userName: user);
    if (newUserName != null && newUserName != user) {
      Map<String, dynamic> formData = {
        EUserDataUpdate.idusuario.name: widget.idUser,
        EUserDataUpdate.usuario.name: newUserName,
      };
      final response = await _usuarioService.updateUserName(formData);
      if (response.success) {
        if (mounted) setState(() => user = newUserName);
        _preferences.setString('Usuario', newUserName);
        MessengerService.info('Nombre de usuario actualizado');
      } else {
        MessengerService.info(response.message);
      }
      if (mounted) setState(() => editionMode = false);
    } else if (newUserName != null) {
      MessengerService.info('No se hicieron cambios');
    }
  }

  Future<void> _editPassword() async {
    final newPassword = await _showPasswordDialog(context, password: password);
    if (newPassword != null && newPassword != password) {
      Map<String, dynamic> formData = {
        EUserDataUpdate.idusuario.name: widget.idUser,
        EUserDataUpdate.password.name: newPassword,
      };
      final response = await _usuarioService.updatePassword(formData);
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
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
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
                            icon: Icon(
                              showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                            ),
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
                            icon: Icon(
                              showNewPassword ? Icons.visibility_off : Icons.visibility,
                            ),
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
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancelar'),
                ),
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
    late final List<LabelFieldBase> fields = [
      LabelEmailField(
        editionMode,
        fieldsVC['Email']?.value,
        fieldsVC['Email']?.controller,
        'Correo',
        true,
        icon: Icons.mail,
      ),
      LabelNumberField(
        editionMode,
        fieldsVC['NumCelular']!.value,
        fieldsVC['NumCelular']!.controller,
        'Teléfono',
        10,
        10,
        true,
        icon: Icons.phone,
      ),
    ];

    final List<InfoRow> fieldsAccess = [
      InfoRow(user, icon: Icons.person, label: 'Usuario', onAction: _editUserName),
      InfoRow('********', icon: Icons.key, label: 'Contraseña', onAction: _editPassword)
    ];

    return Scaffold(
        appBar: AppBarHeader('Datos de tu cuenta', actions: [
          IconButton(
            tooltip: 'Editar',
            isSelected: editionMode,
            onPressed: _edition,
            icon: const Icon(Icons.edit),
            selectedIcon: const Icon(Icons.save),
          ),
          if (editionMode)
            IconButton(
              tooltip: 'Cancelar edición',
              onPressed: () {
                if (mounted) setState(() => editionMode = false);
                _setControllersInitialData();
              },
              icon: const Icon(Icons.close),
            )
        ]),
        body: fieldsVC.entries.length == editableFields.entries.length
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          spacing: 16,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MasonryGridView.count(
                              crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: fields.length,
                              itemBuilder: (context, index) => fields[index],
                            ),
                            if (!editionMode) ...[
                              const Text('Accesos'),
                              MasonryGridView.count(
                                crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: fieldsAccess.length,
                                itemBuilder: (context, index) => fieldsAccess[index],
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )
            : const Center(child: CircularProgressIndicator()));
  }
}
