import 'package:flutter/material.dart';

import '../../domain/models/report_model.dart';
import 'material_report_form.dart';

/// Hoja modal inferior para enviar un reporte sobre un material publicado (#406, #407).
class MaterialReportSheet extends StatelessWidget {
  final String materialId;
  final String materialTitle;
  final void Function(Report report)? onReportCreated;

  const MaterialReportSheet({
    super.key,
    required this.materialId,
    required this.materialTitle,
    this.onReportCreated,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: MaterialReportForm(
          materialId: materialId,
          materialTitle: materialTitle,
          onReportCreated: onReportCreated,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
