import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/validators/form_validators.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/forms/fields_control.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/helpers/connection_helper.dart';
import 'package:gaso_tenant_app/core/helpers/regexp_helper.dart';
import 'package:gaso_tenant_app/features/profile/presentation/widgets/family_contact_dialog.dart';
import 'package:gaso_tenant_app/features/profile/data/profile_service.dart';
import 'package:gaso_tenant_app/features/profile/data/constants.dart';
import 'package:gaso_tenant_app/features/profile/domain/profile.dart';

class PersonalScreen extends StatefulWidget {
  final int? idUser;
  const PersonalScreen({super.key, required this.idUser});

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final SharedPreferences _preferences;
  final ProfileService _usuarioService = ProfileService();

  bool editionMode = false;
  Map<String, FieldValueControl> fieldsVC = {};
  final Map<String, EditableField> editableFields = {
    'Nombre': EditableField(EUserDataUpdate.nombre),
    'CorreoPersonal': EditableField(EUserDataUpdate.correopersonal),
    'NumCelularSecundario': EditableField(EUserDataUpdate.numcelularsecundario),
    'FechaNacimiento': EditableField(EUserDataUpdate.fechanacimiento, type: FVCType.date),
    'CURP': EditableField(EUserDataUpdate.curp),
    'RFC': EditableField(EUserDataUpdate.rfc),
    'NSS': EditableField(EUserDataUpdate.nss),
    'ContactoEmergencia': EditableField(EUserDataUpdate.contactoemergencia, type: FVCType.number),
  };
  Map<int, FamilyContact> familyEmergencyContacts = {};
  int? bloodId;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((preferences) async => {_preferences = preferences, _getUserData()});
  }

  void _getUserData() {
    // información personal
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
    if (mounted) setState(() => fieldsVC = fieldsFromEF);

    // tipo de sangre
    String? idTipoSangre = _preferences.getString('IdTipoSangre') ?? '';
    int? tipoSangre = int.tryParse(idTipoSangre);
    if (mounted) setState(() => bloodId = tipoSangre ?? bloodId);

    // contactos familiar
    String? prefFEC = _preferences.getString('ContactosEmergenciaFami') ?? '';
    List<dynamic> contactList = prefFEC.isNotEmpty ? jsonDecode(prefFEC) : [];
    if (contactList.isNotEmpty) {
      for (var i = 0; i < contactList.length; i++) {
        dynamic contact = contactList[i];
        FamilyContact familyContact = FamilyContact(
            contactId: contact['IdContacto'] ?? 0,
            parentId: contact['IdParentesco'] ?? 0,
            parentName: contact['Nombre'] ?? '',
            contactNumber: contact['TelefonoEmergencia'] ?? '');
        familyEmergencyContacts.addAll({i: familyContact});
      }
    }
    _setControllersInitialData();
  }

  Future<void> _setControllersInitialData() async {
    for (var field in editableFields.entries) {
      fieldsVC[field.key]?.setValueToControl();
    }
  }

  Future<void> _setSavedData(List<FieldValueControl> changedValues) async {
    for (var field in changedValues) {
      fieldsVC[field.spName]?.setControlToValue();
      await _preferences.setString(field.spName, fieldsVC[field.spName]?.value ?? '');
    }
  }

  Future<void> _edition() async {
    if (!editionMode) {
      if (mounted) setState(() => editionMode = true);
    } else if (_formKey.currentState!.validate()) {
      if (!hasConnection(context)) return;
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

  Future<void> _editFamilyContact(FamilyContact contact, int key) async {
    final newContact = await showFamilyContactDialog(context: context, existingContact: contact);
    if (newContact != null) {
      bool parentIdChanged = contact.parentId != newContact.parentId;
      bool parentNameChanged = contact.parentName != newContact.parentName;
      bool contactNumberChanged = contact.contactNumber != newContact.contactNumber;
      if (parentIdChanged || parentNameChanged || contactNumberChanged) {
        Map<String, dynamic> formData = {'idUsuario': widget.idUser, 'IdContacto': contact.contactId};
        if (parentIdChanged) {
          formData.addAll({'IdParentesco': newContact.parentId});
        }
        if (parentNameChanged) {
          formData.addAll({'Nombre': newContact.parentName});
        }
        if (contactNumberChanged) {
          formData.addAll({'TelefonoEmergencia': newContact.contactNumber});
        }
        final response = await _usuarioService.updateContact(formData);
        if (response.success) {
          __updateFamilyContactList(newContact, key);
          if (mounted) {
            setState(() {
              familyEmergencyContacts[key]?.contactId = contact.contactId;
              familyEmergencyContacts[key]?.parentId = newContact.parentId;
              familyEmergencyContacts[key]?.parentName = newContact.parentName;
              familyEmergencyContacts[key]?.contactNumber = newContact.contactNumber;
            });
          }
          MessengerService.info('Contacto actualizado');
        } else {
          MessengerService.info(response.message);
        }
        if (mounted) setState(() => editionMode = false);
      }
    }
  }

  List<dynamic> _getFamilyContactList() {
    String? prefFEC = _preferences.getString('ContactosEmergenciaFami') ?? '';
    return prefFEC.isNotEmpty ? jsonDecode(prefFEC) : [];
  }

  void __updateFamilyContactList(FamilyContact contact, int index) {
    List<dynamic> contactList = _getFamilyContactList();
    contactList[index] = {
      'IdContacto': contact.contactId,
      'IdParentesco': contact.parentId,
      'Nombre': contact.parentName,
      'TelefonoEmergencia': contact.contactNumber,
    };
    String parsedList = jsonEncode(contactList);
    _preferences.setString('ContactosEmergenciaFami', parsedList);
  }

  @override
  Widget build(BuildContext context) {
    final List<LabelFieldBase> fields = [
      LabelTextField(editionMode, fieldsVC['Nombre']?.value, fieldsVC['Nombre']?.controller, 'Nombre',
          icon: Icons.person, customValidator: (value) => FormValidators.required(value, 'el nombre')),
      LabelEmailField(editionMode, fieldsVC['CorreoPersonal']?.value,
          fieldsVC['CorreoPersonal']?.controller, 'Correo personal', true,
          icon: Icons.mail),
    ];

    final List<StatelessWidget> fieldsGeneral = [
      LabelNumberField(editionMode, fieldsVC['NumCelularSecundario']?.value,
          fieldsVC['NumCelularSecundario']?.controller, 'Numero secundario', 10, 10, false,
          icon: Icons.phone_android, label: 'Secundario'),
      LabelDateField(editionMode, fieldsVC['FechaNacimiento']?.value,
          fieldsVC['FechaNacimiento']?.controller, 'Fecha de nacimiento', false,
          icon: Icons.cake, label: 'Fecha de nacimiento'),
      LabelTextField(editionMode, fieldsVC['CURP']?.value, fieldsVC['CURP']?.controller, 'CURP',
          icon: Icons.assignment_ind,
          label: 'CURP',
          capitalization: true,
          formatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(18)],
          customValidator: (value) => FormValidators.valueRegex(value, false, curpRegExp, 'el CURP')),
      LabelTextField(editionMode, fieldsVC['RFC']?.value, fieldsVC['RFC']?.controller, 'RFC',
          icon: Icons.badge,
          label: 'RFC',
          capitalization: true,
          formatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(13)],
          customValidator: (value) => FormValidators.valueRegex(value, false, rfcRegExp, 'el RFC')),
      LabelNumberField(
          editionMode, fieldsVC['NSS']?.value, fieldsVC['NSS']?.controller, 'NSS', 11, 11, false,
          icon: Icons.medical_information, label: 'NSS'),
      if (!editionMode) InfoRow(tiposSangre[bloodId] ?? '?', icon: Icons.bloodtype, label: 'Tipo de sangre'),
      LabelNumberField(editionMode, fieldsVC['ContactoEmergencia']?.value,
          fieldsVC['ContactoEmergencia']?.controller, 'Contacto de emergencia', 10, 10, false,
          icon: Icons.contact_emergency, label: 'Emergencias'),
    ];

    final List<InfoRow> fieldsContact = familyEmergencyContacts.entries.map((contact) {
      return InfoRow(
        contact.value.contactNumber,
        icon: Icons.contact_phone,
        label: contact.value.parentName,
        onAction: () {
          _editFamilyContact(contact.value, contact.key);
        },
      );
    }).toList();

    return Scaffold(
        appBar: AppBarHeader('Información personal', actions: [
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
            ? LayoutBuilder(builder: (context, constraints) {
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
                          if (!editionMode) const Text('Datos generales'),
                          MasonryGridView.count(
                            crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: fieldsGeneral.length,
                            itemBuilder: (context, index) => fieldsGeneral[index],
                          ),
                          if (!editionMode) ...[
                            const Text('Contactos de familiares'),
                            MasonryGridView.count(
                              crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: fieldsContact.length,
                              itemBuilder: (context, index) => fieldsContact[index],
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              })
            : const Center(child: CircularProgressIndicator()));
  }
}
