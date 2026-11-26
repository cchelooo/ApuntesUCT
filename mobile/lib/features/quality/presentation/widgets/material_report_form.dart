import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/report_model.dart';
import '../../domain/models/report_motive.dart';
import '../providers/material_report_provider.dart';

/// Formulario de reporte de materiales conectado a Quality Service mediante Gateway (#398, #406).
///
/// - Utiliza los motivos contractuales de `quality.openapi.json` (`ReportMotive` / `ReportReason`).
/// - Exige `details` cuando el motivo es `OTHER` y valida el límite contractual de 2000 caracteres.
/// - Puede conectarse automáticamente a [materialReportProvider] con el `materialId` real o
///   invocar un callback explícito [onSubmit] cuando se inyecta en pruebas unitarias aisladas.
/// - Conserva la entrada del usuario ante rechazos o errores de red sin simular reportes locales.
/// - Si un `401` invalida la sesión, conserva lo escrito y exige reautenticación antes de permitir reenviar.
class MaterialReportForm extends ConsumerStatefulWidget {
  final String materialId;
  final String materialTitle;
  final bool isSubmitting;
  final String? errorMessage;
  final void Function(ReportMotive motive, String description)? onSubmit;
  final void Function(Report report)? onReportCreated;

  const MaterialReportForm({
    super.key,
    required this.materialId,
    required this.materialTitle,
    this.isSubmitting = false,
    this.errorMessage,
    this.onSubmit,
    this.onReportCreated,
  });

  @override
  ConsumerState<MaterialReportForm> createState() => _MaterialReportFormState();
}

class _MaterialReportFormState extends ConsumerState<MaterialReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  ReportMotive? _selectedMotive;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool effectiveSubmitting, bool requiresReauth) async {
    if (effectiveSubmitting || requiresReauth) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final motive = _selectedMotive!;
    final description = _descriptionController.text.trim();

    if (widget.onSubmit != null) {
      widget.onSubmit!(motive, description);
      return;
    }

    final created = await ref
        .read(materialReportProvider(widget.materialId).notifier)
        .submit(
          materialId: widget.materialId,
          motive: motive,
          details: description,
        );

    if (!mounted) return;
    if (created != null) {
      widget.onReportCreated?.call(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerState = widget.onSubmit == null
        ? ref.watch(materialReportProvider(widget.materialId))
        : const MaterialReportSubmissionState.idle();

    final effectiveSubmitting =
        widget.isSubmitting || providerState.isSubmitting;
    final effectiveError = widget.errorMessage ?? providerState.errorMessage;
    final requiresReauth =
        widget.onSubmit == null && providerState.requiresReauthentication;

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
              child: Text(
                effectiveError,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
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
            onPressed: (effectiveSubmitting || requiresReauth)
                ? null
                : () => _submit(effectiveSubmitting, requiresReauth),
            child: effectiveSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    requiresReauth
                        ? 'Inicia sesión para enviar'
                        : 'Enviar Reporte',
                  ),
          ),
        ],
      ),
    );
  }
}
