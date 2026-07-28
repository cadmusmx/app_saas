import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gaso_tenant_app/features/material_logistics/data/logistics_catalogs_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/forms/controllers_manager.dart';
import 'package:gaso_tenant_app/core/forms/fields_control.dart';
import 'package:gaso_tenant_app/core/validators/form_validators.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/helpers/regexp_helper.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/lists/labels.dart';
import 'package:gaso_tenant_app/core/widgets/media/photo_picker.dart';
import 'package:gaso_tenant_app/core/widgets/lists/tiles.dart';
import 'package:gaso_tenant_app/core/services/image_service.dart';
import 'package:gaso_tenant_app/core/services/location_service.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/selection/option_sl.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/logistics_catalogs.dart';
import 'package:gaso_tenant_app/features/material_logistics/domain/sitio_draft.dart';
import 'package:gaso_tenant_app/features/material_logistics/presentation/material_logistics_holder.dart';

/// Sub-form de captura de un sitio.
/// Recibe una `copy()` del SitioDraft (o uno nuevo) y la edita en local;
/// Al guardar valida y hace `upsertSitio`.
/// Cancelar (pop sin guardar) descarta la copia, dejando el original intacto.
class SitesForm extends StatefulWidget {
  const SitesForm({super.key, required this.draft, this.index});

  final SitioDraft draft;
  final int? index; // null = sitio nuevo

  @override
  State<SitesForm> createState() => _SitesFormState();
}

class _SitesFormState extends State<SitesForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = ControllersManager();
  late final LogisticsCatalogs? _catalogs;
  final ImageService _imageService = ImageService();
  final LocationService _locationService = LocationService();
  final PhotoPicker _photoPicker = PhotoPicker();

  late final MaterialLogisticsHolder _holder;
  late final SitioDraft _draft;
  String _watermark = '';
  bool _isBuilding = true;

  @override
  void initState() {
    super.initState();
    _holder = context.read<MaterialLogisticsHolder>();
    _draft = widget.draft;
    _loadData();
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      _catalogs = await LogisticsCatalogsCache.instance.load();
      _controllers.setValue('idSitio', _draft.idSitio);
      _controllers.setValue('nombreSitio', _draft.nombreSitio);
      _controllers.setValue('descripcionMaterial', _draft.descripcionMaterial);
      _controllers.setValue('descripcionFaltantes', _draft.descripcionFaltantes ?? '');
      _controllers.setValue('descripcionIncidencias', _draft.descripcionIncidencias ?? '');
      // Reconciliar tipos restaurados (de un borrador) contra el catálogo vigente.
      final materialTypes = _catalogs?.materialTypes ?? const <OptionSL>[];
      final incidenceTypes = _catalogs?.incidenceTypes ?? const <OptionSL>[];
      _draft.tipos.removeWhere((id) => !materialTypes.any((o) => o.value == '$id'));
      _draft.incidencias.removeWhere((id) => !incidenceTypes.any((o) => o.value == '$id'));
      // Marca de agua: fecha del arribo + GPS (no bloqueante si el GPS falla).
      final fecha = getFormattedDate(_holder.fecha!, 'dd/MM/yyyy');
      try {
        final loc = await _locationService.getCurrentLocation();
        _watermark = loc != null ? '$fecha\n${loc.latitude},${loc.longitude}' : fecha;
      } catch (e) {
        DebugLog.warning('GPS no disponible para watermark: $e');
        _watermark = fecha;
      }
    } catch (e) {
      DebugLog.error('Error _loadData sitio: $e');
      MessengerService.error('Ocurrió un error al cargar los catálogos');
    } finally {
      if (mounted) setState(() => _isBuilding = false);
    }
  }

  /// Combo [Id-Nombre] único por arribo (case-insensitive), excluyendo el propio.
  bool _comboDuplicado() {
    final id = _controllers.getValue('idSitio').trim().toLowerCase();
    final nombre = _controllers.getValue('nombreSitio').trim().toLowerCase();
    for (var i = 0; i < _holder.sitios.length; i++) {
      if (i == widget.index) continue; // no compararse consigo mismo en edición
      final s = _holder.sitios[i];
      if (s.idSitio.trim().toLowerCase() == id && s.nombreSitio.trim().toLowerCase() == nombre) {
        return true;
      }
    }
    return false;
  }

  Widget _tiposSelector() {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    return FormField<Set<int>>(
      validator: (_) => _draft.tipos.isEmpty ? 'Selecciona al menos un tipo de material' : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'Tipo de material ${_holder.re ? 'recibido' : 'entregado'}',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (_catalogs?.materialTypes ?? const <OptionSL>[]).map((e) {
              final id = int.parse(e.value);
              return FilterChip(
                label: Text(e.text),
                selected: _draft.tipos.contains(id),
                onSelected: (sel) => setState(() {
                  sel ? _draft.tipos.add(id) : _draft.tipos.remove(id);
                  state.didChange(_draft.tipos);
                }),
              );
            }).toList(),
          ),
          if (state.hasError) Text(state.errorText!, style: TextStyle(color: colorScheme.error, fontSize: 12)),
        ],
      ),
    );
  }

  // Evidencias

  Future<void> _addEditEvidencia([int? index]) async {
    String? idTipoForm = index != null ? '${_draft.evidencias[index].idTipoEvidencia}' : null;
    String? localPath;
    String? mimeType;
    String existingFileName = '';
    if (index != null && _draft.evidencias[index].archivo.isNotEmpty) {
      existingFileName = _draft.evidencias[index].archivo.split('/').last;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: Text(index != null ? 'Editar evidencia' : 'Agregar evidencia'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: idTipoForm,
                    decoration: inputDec('Tipo de evidencia'),
                    items: (_catalogs?.evidenceTypes ?? const <OptionSL>[])
                        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.text)))
                        .toList(),
                    onChanged: (v) => setDlgState(() => idTipoForm = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        localPath != null
                            ? localPath!.split('/').last
                            : (existingFileName.isNotEmpty ? existingFileName : 'Seleccionar archivo'),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () async {
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                        );
                        if (picked == null || picked.files.single.path == null) return;
                        const maxBytes = 5 * 1024 * 1024; // 5 MB (gate de entrada)
                        if (picked.files.single.size > maxBytes) {
                          return MessengerService.info('El archivo supera el máximo de 5 MB.');
                        }
                        final ext = picked.files.single.extension?.toLowerCase() ?? '';
                        final isPDF = ext == 'pdf';
                        String? path = picked.files.single.path;
                        // Mime del archivo tal como está hoy (antes de intentar el watermark).
                        String fileMime = isPDF ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
                        if (!isPDF) {
                          try {
                            final wm = await _imageService.waterMarkImage(picked.files.single.xFile, _watermark);
                            path = wm.path;
                            fileMime = ImageService.watermarkMimeType; // el watermark SIEMPRE produce PNG
                          } catch (e) {
                            DebugLog.error('Error aplicando watermark: $e');
                            // Sin watermark: se usa el original con su mime real (ya en fileMime).
                          }
                        }
                        setDlgState(() {
                          localPath = path;
                          mimeType = fileMime;
                        });
                      },
                    ),
                  ),
                  if (index != null && existingFileName.isNotEmpty && localPath == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Archivo actual: $existingFileName', style: Theme.of(ctx).textTheme.bodySmall),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () {
                    if (idTipoForm == null) {
                      return MessengerService.info('Selecciona el tipo de evidencia.');
                    }
                    if (index == null && localPath == null) {
                      return MessengerService.info('Selecciona un archivo.');
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;
    final id = int.parse(idTipoForm!);
    setState(() {
      if (index != null) {
        final e = _draft.evidencias[index];
        e.idTipoEvidencia = id;
        if (localPath != null) {
          e.localPath = localPath;
          e.mimeType = mimeType ?? e.mimeType;
        }
      } else {
        _draft.evidencias.add(
          EvidenceDraft(
            idTipoEvidencia: id,
            archivo: '',
            mimeType: mimeType ?? '',
            orden: _draft.evidencias.length,
            localPath: localPath,
          ),
        );
      }
    });
  }

  /// Borrar = quitar de la lista;
  /// El diff por baseline del SitioDraft lo manda a `evidenciasDel` si estaba persistida.
  /// No hay reciclaje de ids.
  void _removeEvidencia(int index) {
    setState(() => _draft.evidencias.removeAt(index));
  }

  // Visor genérico (lo comparten evidencias y tarimas)
  Future<void> _verArchivo(String? localPath, String key) async {
    if (localPath != null && localPath.isNotEmpty) {
      await OpenFilex.open(localPath);
      return;
    }
    if (key.isEmpty) MessengerService.info('Archivo no encontrado.');
    try {
      final uri = Uri.parse('${Config.s3Url}$key');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        MessengerService.info('No se pudo abrir el archivo $key');
      }
    } catch (e) {
      DebugLog.warning('_verArchivo $e');
      MessengerService.info('No se pudo abrir el documento.');
    }
  }

  Future<void> _verDocumento(EvidenceDraft e) => _verArchivo(e.localPath, e.archivo);

  Future<String?> _pickFoto() async {
    final picked = await _photoPicker.pickPhoto(context);
    if (picked == null) return null;
    if (await picked.length() > 5 * 1024 * 1024) {
      if (mounted) MessengerService.info('La imagen supera el máximo de 5 MB.');
      return null;
    }
    try {
      final wm = await _imageService.waterMarkImage(picked, _watermark);
      return wm.path; // PNG con marca de agua
    } catch (e) {
      DebugLog.error('Error watermark tarima: $e');
      return picked.path; // sin watermark, original
    }
  }

  Widget _evidenciaItem(int index) {
    final e = _draft.evidencias[index];
    final tipo = (_catalogs?.evidenceTypes ?? const <OptionSL>[]).getByValue('${e.idTipoEvidencia}')?.text ?? '';
    final fileRef = e.localPath ?? e.archivo;
    final hasFile = fileRef.isNotEmpty;
    final isPdf = e.mimeType.contains('pdf') || fileRef.toLowerCase().contains('.pdf');
    final icon = !hasFile ? Icons.attach_file : (isPdf ? Icons.picture_as_pdf : Icons.image);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasFile)
                  Text(
                    fileRef.split('/').last,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (hasFile)
            IconButton(tooltip: 'Ver documento', onPressed: () => _verDocumento(e), icon: const Icon(Icons.visibility)),
          IconButton(onPressed: () => _addEditEvidencia(index), icon: const Icon(Icons.edit)),
          IconButton(onPressed: () => _removeEvidencia(index), icon: const Icon(Icons.delete)),
        ],
      ),
    );
  }

  // 5) Tarimas: alta/edición (par de fotos, ambas requeridas), borrar e ítem.
  Future<void> _addEditTarima([int? index]) async {
    final existing = index != null ? _draft.tarimas[index] : null;
    String? tarimaLocal = existing?.tarimaLocalPath;
    String? papeletaLocal = existing?.papeletaLocalPath;
    final tarimaExisting = existing?.tarimaFoto ?? '';
    final papeletaExisting = existing?.papeletaFoto ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            Widget fotoBtn(String label, String? local, String existingKey, ValueChanged<String> onPick) {
              final hasFile = local != null || existingKey.isNotEmpty;
              return OutlinedButton.icon(
                icon: Icon(hasFile ? Icons.check_circle : Icons.photo_camera),
                label: Text(
                  local != null ? local.split('/').last : (existingKey.isNotEmpty ? '$label cargada' : label),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () async {
                  final p = await _pickFoto();
                  if (p != null) setDlg(() => onPick(p));
                },
              );
            }

            return AlertDialog(
              title: Text(index != null ? 'Editar tarima' : 'Agregar tarima'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  fotoBtn('Foto de tarima', tarimaLocal, tarimaExisting, (p) => tarimaLocal = p),
                  fotoBtn('Foto de papeleta', papeletaLocal, papeletaExisting, (p) => papeletaLocal = p),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () {
                    final hasTarima = tarimaLocal != null || tarimaExisting.isNotEmpty;
                    final hasPapeleta = papeletaLocal != null || papeletaExisting.isNotEmpty;
                    if (!hasTarima || !hasPapeleta) {
                      return MessengerService.info('Carga ambas fotos: tarima y papeleta.');
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;
    setState(() {
      if (index != null) {
        final t = _draft.tarimas[index];
        if (tarimaLocal != null) t.tarimaLocalPath = tarimaLocal;
        if (papeletaLocal != null) t.papeletaLocalPath = papeletaLocal;
      } else {
        _draft.tarimas.add(
          TarimaDraft(
            tarimaFoto: '',
            papeletaFoto: '',
            orden: _draft.tarimas.length + 1,
            tarimaLocalPath: tarimaLocal,
            papeletaLocalPath: papeletaLocal,
          ),
        );
      }
    });
  }

  void _removeTarima(int index) => setState(() => _draft.tarimas.removeAt(index));

  Widget _tarimaItem(int index) {
    final t = _draft.tarimas[index];
    return ListTile(
      title: Text('Tarima ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Wrap(
        spacing: 8,
        children: [
          ActionChip(label: const Text('Ver tarima'), onPressed: () => _verArchivo(t.tarimaLocalPath, t.tarimaFoto)),
          ActionChip(
            label: const Text('Ver papeleta'),
            onPressed: () => _verArchivo(t.papeletaLocalPath, t.papeletaFoto),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: () => _addEditTarima(index), icon: const Icon(Icons.edit)),
          IconButton(onPressed: () => _removeTarima(index), icon: const Icon(Icons.delete)),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return MessengerService.info('Corrige los campos marcados.');
    }
    if (_comboDuplicado()) {
      return MessengerService.info('Ya existe un sitio con ese Id y nombre en este arribo.');
    }
    if (_draft.evidencias.isEmpty) {
      return MessengerService.info('Agrega al menos una evidencia.');
    }
    _draft.idSitio = _controllers.getValue('idSitio').trim();
    _draft.nombreSitio = _controllers.getValue('nombreSitio').trim();
    _draft.descripcionMaterial = _controllers.getValue('descripcionMaterial').trim();
    _draft.descripcionFaltantes = _draft.materialFaltante ? _controllers.getValue('descripcionFaltantes').trim() : null;
    _draft.descripcionIncidencias = _draft.incidencias.isNotEmpty
        ? _controllers.getValue('descripcionIncidencias').trim()
        : null;
    _holder.upsertSitio(_draft, index: widget.index);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final identity = <Widget>[
      TextFormField(
        controller: _controllers.get('idSitio'),
        decoration: inputDec('Id del sitio', hint: 'Ej. 12A'),
        validator: (v) => FormValidators.required(v, 'Id del sitio'),
        inputFormatters: [
          LengthLimitingTextInputFormatter(100),
          FilteringTextInputFormatter.deny(notUsedExp),
          UpperCaseTextFormatter(),
        ],
      ),
      TextFormField(
        controller: _controllers.get('nombreSitio'),
        decoration: inputDec('Nombre del sitio', hint: 'Ej. Norte'),
        validator: (v) => FormValidators.required(v, 'nombre del sitio'),
        inputFormatters: [
          LengthLimitingTextInputFormatter(200),
          FilteringTextInputFormatter.deny(notUsedExp),
          UpperCaseTextFormatter(),
        ],
      ),
    ];

    final material = <Widget>[
      TextFormField(
        controller: _controllers.get('descripcionMaterial'),
        decoration: inputDec(
          'Descripción del material ${_holder.re ? 'recibido' : 'entregado'}',
          hint: 'Ejemplo: 12 pallets, 4 gabinetes BBU, 3 cajas RF',
        ),
        maxLines: 3,
        validator: (v) => FormValidators.required(v, 'descripción del material'),
        inputFormatters: [LengthLimitingTextInputFormatter(250), FilteringTextInputFormatter.deny(notUsedExp)],
      ),
      DropdownButtonFormField<bool>(
        isExpanded: true,
        initialValue: _draft.materialFaltante,
        decoration: inputDec('¿Material faltante?'),
        items: const [
          DropdownMenuItem(value: true, child: Text('Sí')),
          DropdownMenuItem(value: false, child: Text('No')),
        ],
        onChanged: (v) => setState(() => _draft.materialFaltante = v ?? _draft.materialFaltante),
      ),
      if (_draft.materialFaltante)
        TextFormField(
          controller: _controllers.get('descripcionFaltantes'),
          decoration: inputDec('Describir faltantes', hint: 'Ejemplo: Falta pallet #7, falta gabinete BBU-02'),
          maxLines: 2,
          validator: (v) => FormValidators.required(v, 'descripción de faltantes'),
          inputFormatters: [LengthLimitingTextInputFormatter(500), FilteringTextInputFormatter.deny(notUsedExp)],
        ),
    ];

    return Scaffold(
      appBar: AppBarHeader(widget.index == null ? 'Nuevo sitio' : 'Editar sitio'),
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
                          MasonryGridView.count(
                            crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: identity.length,
                            itemBuilder: (context, index) => identity[index],
                          ),
                          SectionTitle('Validación de material'),
                          _tiposSelector(),
                          MasonryGridView.count(
                            crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: material.length,
                            itemBuilder: (context, index) => material[index],
                          ),
                          ExpansionListTile(
                            'Evidencia fotográfica',
                            'Imagen o PDF. Máximo 5 MB por archivo.',
                            () {
                              if (_draft.evidencias.length >= 10) {
                                return MessengerService.info('Máximo 10 archivos.');
                              }
                              _addEditEvidencia();
                            },
                            children: [for (int i = 0; i < _draft.evidencias.length; i++) _evidenciaItem(i)],
                          ),
                          ExpansionListTile(
                            'Tarimas',
                            'Cada registro requiere foto de tarima y de papeleta. Máximo 50.',
                            () {
                              if (_draft.tarimas.length >= 50) {
                                return MessengerService.info('Máximo 50 tarimas por sitio.');
                              }
                              _addEditTarima();
                            },
                            children: [for (int i = 0; i < _draft.tarimas.length; i++) _tarimaItem(i)],
                          ),
                          SectionTitle('Incidencias', subtitle: '¿Hubo incidencias?'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: (_catalogs?.incidenceTypes ?? const <OptionSL>[]).map((e) {
                              final id = int.parse(e.value);
                              return FilterChip(
                                label: Text(e.text),
                                selected: _draft.incidencias.contains(id),
                                onSelected: (sel) => setState(() {
                                  if (sel) {
                                    _draft.incidencias.add(id);
                                  } else {
                                    _draft.incidencias.remove(id);
                                    if (_draft.incidencias.isEmpty) _controllers.setValue('descripcionIncidencias', '');
                                  }
                                }),
                              );
                            }).toList(),
                          ),
                          if (_draft.incidencias.isNotEmpty)
                            TextFormField(
                              controller: _controllers.get('descripcionIncidencias'),
                              decoration: inputDec('Descripción de incidencias'),
                              maxLines: 3,
                              validator: (v) => FormValidators.required(v, 'descripción de incidencias'),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(500),
                                FilteringTextInputFormatter.deny(notUsedExp),
                              ],
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: FilledButton.tonal(onPressed: _save, child: Text('GUARDAR SITIO')),
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
