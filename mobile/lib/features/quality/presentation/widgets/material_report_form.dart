import 'package:flutter/material.dart';

import '../../domain/models/report_motive.dart';

/// Formulario local para el reporte de materiales.
///
/// Valida datos localmente y retiene la entrada ante errores.
/// Los códigos de motivos y esquemas son provisionales (pendiente #444).
/// No incluye llamadas de red directas a Quality service en esta etapa.
class MaterialReportForm extends StatefulWidget {
  final String materialId;
  final String materialTitle;
  final bool isSubmitting;
  final String? errorMessage; // Permite mostrar errores externos (ej. error de red) sin borrar el form
  final void Function(ReportMotive motive, String description) onSubmit;

  const MaterialReportForm({
    super.key,
    required this.materialId,
    required this.materialTitle,
    this.isSubmitting = false,
    this.errorMessage,
    required this.onSubmit,
  });

  @override
  State<MaterialReportForm> createState() => _MaterialReportFormState();
}

class _MaterialReportFormState extends State<MaterialReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  ReportMotive? _selectedMotive;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(_selectedMotive!, _descriptionController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
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

          if (widget.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          DropdownButtonFormField<ReportMotive>(
            initialValue: _selectedMotive, // <-- Si persiste el error aquí, cambia DropdownButtonFormField por DropdownButton
            decoration: const InputDecoration(
              labelText: 'Motivo del reporte *',
              border: OutlineInputBorder(),
            ),
            items: ReportMotive.values.map((motive) {
              return DropdownMenuItem(value: motive, child: Text(motive.label));
            }).toList(),
            onChanged: widget.isSubmitting
                ? null
                : (value) => setState(() => _selectedMotive = value),
            validator: (value) => value == null
                ? 'Por favor, seleccione un motivo obligatorio.'
                : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            enabled: !widget.isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Detalles adicionales (Opcional)',
              border: OutlineInputBorder(),
              hintText: 'Explique brevemente el problema...',
            ),
            maxLines: 3,
            maxLength: 500,
            validator: (value) {
              if (value != null && value.length > 500) {
                return 'El detalle no puede superar los 500 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: widget.isSubmitting ? null : _submit,
            child: widget.isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar Reporte'),
          ),
        ],
      ),
    );
  }
}
