import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/report_model.dart';
import '../../domain/models/report_motive.dart';
import '../providers/material_report_provider.dart';

/// Formulario de reporte de materiales con estados de carga, confirmación y error (#398, #406, #407).
///
/// Cumple con los criterios de aceptación de S3-M19 y S3-M20:
/// - Muestra estado de carga y deshabilita controles mientras la solicitud está pendiente.
/// - Muestra vista de confirmación únicamente después de recibir la respuesta exitosa del servidor.
/// - Conserva el motivo seleccionado y el texto ingresado ante errores y permite reintentar.
/// - Bloquea toques repetidos de forma síncrona y asíncrona para evitar solicitudes duplicadas.
class MaterialReportForm extends ConsumerStatefulWidget {
  final String materialId;
  final String materialTitle;
  final bool isSubmitting;
  final String? errorMessage;
  final Report? confirmedReport;
  final void Function(ReportMotive motive, String description)? onSubmit;
  final void Function(Report report)? onReportCreated;
  final VoidCallback? onClose;

  const MaterialReportForm({
    super.key,
    required this.materialId,
    required this.materialTitle,
    this.isSubmitting = false,
    this.errorMessage,
    this.confirmedReport,
    this.onSubmit,
    this.onReportCreated,
    this.onClose,
  });

  @override
  ConsumerState<MaterialReportForm> createState() => _MaterialReportFormState();
}

class _MaterialReportFormState extends ConsumerState<MaterialReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  ReportMotive? _selectedMotive;
  bool _inFlight = false;
  bool _completedHere = false;

  @override
  void initState() {
    super.initState();
    if (widget.onSubmit == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = ref.read(materialReportProvider(widget.materialId));
        if (current.hasError || current.isSuccess) {
          ref.read(materialReportProvider(widget.materialId).notifier).reset();
        }
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool effectiveSubmitting) async {
    if (effectiveSubmitting || _inFlight) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final motive = _selectedMotive!;
    final description = _descriptionController.text.trim();

    if (widget.onSubmit != null) {
      widget.onSubmit!(motive, description);
      return;
    }

    setState(() => _inFlight = true);
    try {
      final created = await ref
          .read(materialReportProvider(widget.materialId).notifier)
          .submit(
            materialId: widget.materialId,
            motive: motive,
            details: description,
          );

      if (!mounted) return;
      if (created != null) {
        setState(() => _completedHere = true);
        widget.onReportCreated?.call(created);
      }
    } finally {
      if (mounted) {
        setState(() => _inFlight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerState = widget.onSubmit == null
        ? ref.watch(materialReportProvider(widget.materialId))
        : const MaterialReportSubmissionState.idle();

    final effectiveSubmitting =
        widget.isSubmitting || providerState.isSubmitting || _inFlight;
    final effectiveError = widget.errorMessage ?? providerState.errorMessage;
    final confirmedReport =
        widget.confirmedReport ??
        (_completedHere ? providerState.submittedReport : null);

    if (confirmedReport != null && !effectiveSubmitting) {
      return _ReportConfirmationView(
        materialTitle: widget.materialTitle,
        report: confirmedReport,
        onClose:
            widget.onClose ??
            () {
              Navigator.of(context).maybePop();
            },
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reportar Material',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Material: ${widget.materialTitle}',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (effectiveError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          effectiveError,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!effectiveSubmitting && _selectedMotive != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _submit(effectiveSubmitting),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reintentar'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          DropdownButtonFormField<ReportMotive>(
            key: ValueKey<ReportMotive?>(_selectedMotive),
            initialValue: _selectedMotive,
            decoration: const InputDecoration(
              labelText: 'Motivo del reporte *',
              border: OutlineInputBorder(),
            ),
            items: ReportMotive.values.map((motive) {
              return DropdownMenuItem(value: motive, child: Text(motive.label));
            }).toList(),
            onChanged: effectiveSubmitting
                ? null
                : (value) => setState(() => _selectedMotive = value),
            validator: (value) => value == null
                ? 'Por favor, seleccione un motivo obligatorio.'
                : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            enabled: !effectiveSubmitting,
            decoration: InputDecoration(
              labelText: (_selectedMotive?.requiresDetails ?? false)
                  ? 'Detalles adicionales *'
                  : 'Detalles adicionales (Opcional)',
              border: const OutlineInputBorder(),
              hintText: 'Explique brevemente el problema...',
            ),
            maxLines: 3,
            maxLength: 2000,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if ((_selectedMotive?.requiresDetails ?? false) &&
                  trimmed.isEmpty) {
                return 'Debes especificar los detalles cuando seleccionas "Otro motivo".';
              }
              if (value != null && value.length > 2000) {
                return 'El detalle no puede superar los 2000 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: effectiveSubmitting
                ? null
                : () => _submit(effectiveSubmitting),
            child: effectiveSubmitting
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Enviando reporte...'),
                    ],
                  )
                : const Text('Enviar Reporte'),
          ),
        ],
      ),
    );
  }
}

class _ReportConfirmationView extends StatelessWidget {
  final String materialTitle;
  final Report report;
  final VoidCallback onClose;

  const _ReportConfirmationView({
    required this.materialTitle,
    required this.report,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 56,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Reporte enviado',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Tu reporte sobre "$materialTitle" fue recibido por el servidor y quedó registrado en estado ${report.status.label}.',
          style: textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Motivo: ${report.reason.label}',
            style: textTheme.labelMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onClose,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Cerrar'),
        ),
      ],
    );
  }
}
