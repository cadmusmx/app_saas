import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gaso_tenant_app/features/profile/domain/profile.dart';
import 'package:gaso_tenant_app/features/profile/data/constants.dart';

Future<FamilyContact?> showFamilyContactDialog({required BuildContext context, FamilyContact? existingContact}) {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: existingContact?.parentName ?? '');
  final emergencyController = TextEditingController(text: existingContact?.contactNumber ?? '');
  int? selectedParentId = existingContact?.parentId;

  return showDialog<FamilyContact>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(existingContact == null ? 'Nuevo contacto familiar' : 'Editar contacto'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedParentId,
                  decoration: const InputDecoration(labelText: 'Parentesco', border: OutlineInputBorder()),
                  items: parentescos.entries
                      .map((option) => DropdownMenuItem<int>(value: option.key, child: Text(option.value)))
                      .toList(),
                  onChanged: (value) => selectedParentId = value,
                  validator: (value) => value == null ? 'Seleccione un parentesco' : null,
                ),
                TextFormField(
                  controller: nameController,
                  inputFormatters: [LengthLimitingTextInputFormatter(25)],
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    hintText: 'Juan Pérez',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'El Nombre es requerido';
                    return null;
                  },
                ),
                TextFormField(
                  controller: emergencyController,
                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                  decoration: const InputDecoration(
                    labelText: 'Contacto de emergencia',
                    hintText: '5551234567',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'El Contacto es requerido';
                    if (value.trim().length != 10) return 'Deben ser 10 dígitos';
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
                final contact = FamilyContact(
                  contactId: existingContact!.contactId,
                  parentId: selectedParentId!,
                  parentName: nameController.text.trim(),
                  contactNumber: emergencyController.text.trim(),
                );
                Navigator.pop(context, contact);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  );
}
