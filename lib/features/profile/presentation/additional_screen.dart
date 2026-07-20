import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:gaso_tenant_app/app/widgets/appbar_header.dart';
import 'package:gaso_tenant_app/core/widgets/forms/form_fields.dart';
import 'package:gaso_tenant_app/core/widgets/media/visual_dialogs.dart';
import 'package:gaso_tenant_app/core/config/config.dart';
import 'package:gaso_tenant_app/core/services/messenger_service.dart';
import 'package:gaso_tenant_app/core/helpers/formatters_helper.dart';
import 'package:gaso_tenant_app/core/helpers/responsive_helper.dart';
import 'package:gaso_tenant_app/features/profile/data/profile_service.dart';
import 'package:gaso_tenant_app/features/profile/domain/profile.dart';

class AdditionalScreen extends StatefulWidget {
  final int? idUser;
  final String licenseExpiration;
  final String salary;
  const AdditionalScreen({
    super.key,
    required this.idUser,
    required this.licenseExpiration,
    required this.salary,
  });

  @override
  State<AdditionalScreen> createState() => _AdditionalScreenState();
}

class _AdditionalScreenState extends State<AdditionalScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _usuarioService = ProfileService();

  final List<VisualTitle<String>> _documents = [];
  List<DocumentInfo> _documentsInfo = [];
  bool hasLicense = false;
  String licenseExpiration = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    licenseExpiration =
        widget.licenseExpiration.isNotEmpty ? getFormattedDateStr(widget.licenseExpiration, 'dd/MM/yyyy') : '';

    final response = await _usuarioService.getDocuments(widget.idUser ?? 0);
    if (response.success && response.data != null) {
      UserDocuments ud = response.data!;
      if (mounted) {
        setState(
          () => _documentsInfo = [
            DocumentInfo('INE', Icons.person, ud.ine),
            DocumentInfo('CURP', Icons.assignment_ind, ud.curp),
            DocumentInfo('Acta de nacimiento', Icons.article, ud.actaNacimiento),
            DocumentInfo('NSS', Icons.medical_information, ud.nss),
            DocumentInfo('C. Situación Fiscal', Icons.badge, ud.csFiscal),
            DocumentInfo('Comp. Domicilio', Icons.pin_drop, ud.comprobanteDomicilio),
            DocumentInfo('U. G. Estudios', Icons.school, ud.ugEstudios),
            DocumentInfo('EDO. C. Bancario', Icons.account_balance, ud.ecBancaria),
            DocumentInfo('Lic. de conducir', Icons.directions_car, ud.licenciaConducir),
            DocumentInfo('Certificado Medico', Icons.local_hospital, ud.certificadoMedico),
            DocumentInfo('Baja IMSS', Icons.medical_services, ud.bajaIMSS),
            DocumentInfo('Acuerdo confidencial', Icons.policy, ud.acuerdoConfidencial),
            DocumentInfo('Otro', Icons.file_open, ud.otro),
          ],
        );
      }
      int index = 0;
      for (var document in _documentsInfo) {
        if (document.url != null) {
          document.index = index;
          _documents.add(VisualTitle<String>(document.name, '${Config.s3Url}${document.url}'));
          index++;
        }
      }
    } else {
      MessengerService.info(response.message);
    }
  }

  /// mostrar nombre del documento solo si hay url
  String _getDocText(String name, String? url) {
    if (url == null) return '';
    return name;
  }

  /// mostrar label solo si no hay url
  String? _getDocLabel(String name, String? url) {
    if (url != null) return null;
    return name;
  }

  // mostrar acción de vista previa si hay index
  void Function()? _getDocAction(int? index) {
    if (index == null) return null;
    return () async => await showDocumentsDialog(context, documents: _documents, startFrom: index);
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      InfoRow(widget.salary, icon: Icons.attach_money, label: 'Sueldo'),
      InfoRow(licenseExpiration, icon: Icons.event_busy, label: 'Vigencia de licencia'),
    ];

    final docRows = [
      for (var doc in _documentsInfo)
        InfoRow(
          _getDocText(doc.name, doc.url),
          label: _getDocLabel(doc.name, doc.url),
          icon: doc.icon,
          onAction: _getDocAction(doc.index),
          actionIcon: Icons.visibility,
        )
    ];

    return Scaffold(
      appBar: const AppBarHeader('Información adicional'),
      body: LayoutBuilder(
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
                      itemCount: rows.length,
                      itemBuilder: (context, index) => rows[index],
                    ),
                    if (_documents.isNotEmpty) ...[
                      const Text('Documentación'),
                      MasonryGridView.count(
                        crossAxisCount: ResponsiveHelper.crossAxisCount(constraints),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docRows.length,
                        itemBuilder: (context, index) => docRows[index],
                      ),
                    ]
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

class DocumentInfo {
  final String name;
  final IconData icon;
  String? url;

  /// index en el dialog de documentos
  int? index;
  DocumentInfo(this.name, this.icon, this.url, [this.index]);
}
