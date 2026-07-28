import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/header_documents_section.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/router/routes.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/auth/session_user.dart';
import 'package:gaso_tenant_app/core/auth/auth_context.dart';
import 'package:gaso_tenant_app/core/widgets/info/info_letter.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/forms/controllers_manager.dart';
import 'package:gaso_tenant_app/core/forms/fields_control.dart';
import 'package:gaso_tenant_app/core/forms/draft_manager.dart';
import 'package:gaso_tenant_app/core/validators/form_validators.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/forms/dialogs.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/helpers/regexp_helper.dart';
import 'package:gaso_tenant_app/core/extensions/extensions.dart';
import 'package:gaso_tenant_app/core/services/date_time_picker_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/storage/preferences.dart';
import 'package:gaso_tenant_app/core/selection/option_sl.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/logistics_catalogs_service.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/logistics_catalogs.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/material_logistics_holder.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/material_logistics_info.dart';

/// Pantalla de Cabecera del arribo. El valor de cada campo vive en el holder;
/// el State solo tiene `FormKey`, `ControllersManager`, las SL y la sesión.
/// Dropdowns/pickers/toggle escriben al holder en el momento;
/// el texto libre se vuelca con `commitHeader` en "Continuar".
class HeaderForm extends StatefulWidget {
  const HeaderForm({super.key});

  @override
  State<HeaderForm> createState() => _HeaderFormState();
}

class _HeaderFormState extends State<HeaderForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = ControllersManager();
  late final LogisticsCatalogs? _catalogs;
  final Preferences _preferences = Preferences();
  final DraftManager _draftManager = DraftManager('material_logistics_draft');
  late final MaterialLogisticsHolder _holder;
  late final SessionUser _sessionUser;
  bool _isBuilding = true;
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    _holder = context.read<MaterialLogisticsHolder>();
    final session = AuthContext.instance.current;
    if (session != null && session.user.id != null) {
      _sessionUser = session;
      _sessionReady = true;
      _loadData();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MessengerService.info('Ocurrió un error al obtener sus datos');
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    }
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _preferences.init();
      _catalogs = await LogisticsCatalogsCache.instance.load();
      // Pre-llenado de texto libre desde el holder. En creación, Responsable ← nombre de sesión.
      _controllers.setValue(
        'responsable',
        _holder.nombreResponsable ??
            (_holder.isEdition ? (_holder.original?.responsable ?? '') : _sessionUser.user.name),
      );
      _controllers.setValue('unidadPlaca', _holder.unidadPlaca);
      _controllers.setValue('nombreOperador', _holder.nombreOperador);
      _controllers.setValue('otroCarrier', _holder.otroCarrier);
      if (!_holder.isEdition) await _resolveOperationType();
    } catch (e) {
      DebugLog.error('Error _loadData cabecera: $e');
      MessengerService.error('Ocurrió un error al obtener los datos requeridos');
    } finally {
      if (mounted) setState(() => _isBuilding = false);
    }
  }

  /// B-mínimo: si el usuario ya tiene preferencia (lmRE) la hereda sin preguntar; si nunca eligió pregunta.
  /// Si no elige, regresa a Home. Se puede cambiar luego con el toggle en captura.
  /// Solo en creación (en edición RE es inmutable).
  Future<void> _resolveOperationType() async {
    final pref = _preferences.lmRE;
    if (pref != null) {
      _holder.setRe(pref);
      return;
    }
    if (!mounted) return;
    final op = await showOptionsDialog<int>(context, 'Tipo', 'Elija el tipo de operación', {
      'Recepción': 0,
      'Entrega': 1,
    });
    if (!mounted) return;
    if (op == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
      return;
    }
    _holder.setRe(op == 0);
  }

  Future<void> _pickFecha() async {
    final fecha = await DateTimePickerService.pickFechaSola(context, currentValue: _holder.fecha);
    if (fecha != null) _holder.setFecha(fecha);
  }

  Future<void> _pickHora(TimeOfDay? current, ValueChanged<String?> onPicked) async {
    final t = await DateTimePickerService.pickHora(context, currentValue: current);
    if (t != null && mounted) onPicked(t.toApiTime());
  }

  /// Campo de hora read-only. `value` es "HH:mm:ss" del holder;
  /// Al elegir se convierte con `toApiTime()` y se escribe de vuelta.
  Widget _horaField(String label, String? value, ValueChanged<String?> onPicked) {
    final current = parseApiTime(value);
    return TextFormField(
      readOnly: true,
      decoration: inputDec(
        label,
        hint: '--:--',
        flb: FloatingLabelBehavior.always,
        suffix: IconButton(icon: const Icon(Icons.schedule), onPressed: () => _pickHora(current, onPicked)),
      ),
      controller: TextEditingController(text: current != null ? current.format(context) : ''),
      onTap: () => _pickHora(current, onPicked),
      validator: (_) => value == null ? 'Selecciona la hora' : null,
    );
  }

  /// Orden lógico: llegada ≤ inicio ≤ salida.
  String? _validarOrdenHoras() {
    final ll = parseApiTime(_holder.horaLlegada);
    final ini = parseApiTime(_holder.horaInicioDescarga);
    final sal = parseApiTime(_holder.horaSalida);
    if (ll == null || ini == null || sal == null) return 'Completa las tres horas de arribo';
    if (ini.inMinutes < ll.inMinutes) {
      return 'El inicio de ${_holder.re ? "descarga" : "carga"} no puede ser antes de la llegada';
    }
    if (sal.inMinutes < ini.inMinutes) {
      return 'La salida no puede ser antes del inicio de ${_holder.re ? "descarga" : "carga"}';
    }
    return null;
  }

  void _commitHeader() {
    final responsable = _controllers.getValue('responsable').trim();
    // Sentinela "usar al usuario": vacío, el nombre de sesión (creación),
    // o —en edición sobre un registro cuyo responsable era el usuario (nombreResponsable == null)— el nombre original mostrado.
    // Evita que un editor distinto convierta null en override.
    final originalWasUser = _holder.isEdition && _holder.original?.nombreResponsable == null;
    final userDefault = originalWasUser ? (_holder.original?.responsable ?? '') : _sessionUser.user.name;
    _holder.commitHeader(
      nombreResponsable: responsable.isEmpty || responsable == userDefault ? null : responsable,
      unidadPlaca: _controllers.getValue('unidadPlaca').trim(),
      nombreOperador: _controllers.getValue('nombreOperador').trim(),
      otroCarrier: _controllers.getValue('otroCarrier').trim(),
    );
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) {
      return MessengerService.info('Corrige los campos marcados.');
    }
    final ordenError = _validarOrdenHoras();
    if (ordenError != null) return MessengerService.info(ordenError);
    _commitHeader();
    _holder.goToSitios();
  }

  Future<void> _saveDraft() async {
    _commitHeader(); // vuelca el texto libre al holder antes de serializar
    await _draftManager.saveDraft(_holder.buildDraft());
  }

  Future<void> _loadDraft() async {
    final draft = await _draftManager.loadDraft();
    if (draft == null || !mounted) return;
    _holder.loadDraft(draft);
    // Reconciliar dropdowns de cabecera contra catálogo (descartar valores fantasma).
    final xdocks = _catalogs?.xdocks ?? const <OptionSL>[];
    final carriers = _catalogs?.carriers ?? const <OptionSL>[];
    if (xdocks.getByValue(_holder.idXdock ?? '') == null) _holder.setIdXdock(null);
    if (carriers.getByValue(_holder.idCarrier ?? '') == null) {
      _holder.setIdCarrier(null, esOtro: false);
    } else {
      _holder.setIdCarrier(_holder.idCarrier, esOtro: _catalogs?.isCarrierOtro(_holder.idCarrier) ?? false);
    }
    // Reseed del texto libre.
    _controllers.setValue('responsable', _holder.nombreResponsable ?? _sessionUser.user.name);
    _controllers.setValue('unidadPlaca', _holder.unidadPlaca);
    _controllers.setValue('nombreOperador', _holder.nombreOperador);
    _controllers.setValue('otroCarrier', _holder.otroCarrier);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final holder = context.watch<MaterialLogisticsHolder>();
    final colorScheme = Theme.of(context).colorScheme;

    final fields = <Widget>[
      // Toggle de tipo de operación (solo creación; en edición RE es inmutable).
      if (!holder.isEdition)
        FilledButton.icon(
          onPressed: () => _holder.setRe(!_holder.re),
          label: Text(holder.re ? 'RECEPCIÓN' : 'ENTREGA'),
          icon: Icon(holder.re ? Icons.login : Icons.logout),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.secondary,
            foregroundColor: colorScheme.onSecondary,
          ),
        ),
      TextFormField(
        readOnly: true,
        decoration: inputDec(
          'Fecha',
          hint: 'dd/MM/yyyy',
          flb: FloatingLabelBehavior.always,
          suffix: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickFecha),
        ),
        controller: TextEditingController(
          text: holder.fecha != null ? getFormattedDate(holder.fecha!, 'dd/MM/yyyy') : '',
        ),
        onTap: _pickFecha,
        validator: (_) => holder.fecha == null ? 'Selecciona la fecha' : null,
      ),
      Row(
        spacing: 8,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: holder.idXdock,
              decoration: inputDec('XDOCK'),
              items: (_catalogs?.xdocks ?? const <OptionSL>[])
                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.text)))
                  .toList(),
              onChanged: holder.setIdXdock,
              validator: (v) => FormValidators.requiredDropdown(v, 'XDOCK'),
            ),
          ),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: holder.idCarrier,
              decoration: inputDec('Carrier'),
              items: (_catalogs?.carriers ?? const <OptionSL>[])
                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.text)))
                  .toList(),
              onChanged: (v) => holder.setIdCarrier(v, esOtro: _catalogs?.isCarrierOtro(v) ?? false),
              validator: (v) => FormValidators.requiredDropdown(v, 'carrier'),
            ),
          ),
        ],
      ),
      if (holder.carrierEsOtro)
        TextFormField(
          controller: _controllers.get('otroCarrier'),
          decoration: inputDec('Nombre carrier'),
          validator: (v) => FormValidators.required(v, 'carrier'),
          inputFormatters: [LengthLimitingTextInputFormatter(150), FilteringTextInputFormatter.deny(notUsedExp)],
        ),
      TextFormField(
        controller: _controllers.get('responsable'),
        decoration: inputDec('Responsable'),
        validator: (v) => FormValidators.required(v, 'responsable'),
        inputFormatters: [LengthLimitingTextInputFormatter(75), FilteringTextInputFormatter.deny(notUsedExp)],
      ),
      TextFormField(
        controller: _controllers.get('unidadPlaca'),
        decoration: inputDec('Número unidad / placa'),
        validator: (v) => FormValidators.required(v, 'unidad o placa'),
        inputFormatters: [
          LengthLimitingTextInputFormatter(25),
          FilteringTextInputFormatter.deny(notUsedExp),
          UpperCaseTextFormatter(),
        ],
      ),
      TextFormField(
        controller: _controllers.get('nombreOperador'),
        decoration: inputDec('Nombre del operador'),
        validator: (v) => FormValidators.required(v, 'nombre del operador'),
        inputFormatters: [LengthLimitingTextInputFormatter(75), FilteringTextInputFormatter.deny(notUsedExp)],
      ),
    ];

    final fieldsArribo = <Widget>[
      _horaField('Llegada de unidad', holder.horaLlegada, holder.setHoraLlegada),
      _horaField(
        'Inicio de ${holder.re ? 'descarga' : 'carga'}',
        holder.horaInicioDescarga,
        holder.setHoraInicioDescarga,
      ),
      _horaField('Salida de unidad', holder.horaSalida, holder.setHoraSalida),
    ];

    return Scaffold(
      appBar: AppBarHeader(
        holder.re ? 'Recepción de material' : 'Entrega de material',
        leading: holder.isEdition ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: holder.goToSitios) : null,
        actions: holder.isEdition
            ? null
            : [
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    PopupMenuItem(onTap: _loadDraft, child: const Text('Cargar borrador')),
                    PopupMenuItem(onTap: _saveDraft, child: const Text('Guardar borrador')),
                  ],
                ),
              ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: _isBuilding
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(ResponsiveHelper.mainPadding(constraints)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 16,
                        children: [
                          InfoLetterChip(materialLogisticsLetter),
                          MasonryGridView.count(
                            crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: fields.length,
                            itemBuilder: (context, index) => fields[index],
                          ),
                          const HeaderDocumentsSection(),
                          SectionTitle('Control de arribo'),
                          MasonryGridView.count(
                            crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: fieldsArribo.length,
                            itemBuilder: (context, index) => fieldsArribo[index],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  label: Text(holder.isEdition ? 'GUARDAR' : 'CONTINUAR'),
                                  onPressed: _continue,
                                  iconAlignment: IconAlignment.end,
                                  icon: Icon(holder.isEdition ? Icons.check : Icons.arrow_forward),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
