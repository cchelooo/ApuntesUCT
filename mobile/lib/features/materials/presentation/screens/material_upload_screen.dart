import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/widgets/app_primary_button.dart';
import 'package:apuntesuct_mobile/core/widgets/app_text_field.dart';
import 'package:apuntesuct_mobile/core/widgets/form_error_banner.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

enum _UploadSource { file, link }

/// Formulario de subida de material (issue #280).
///
/// Maqueta desacoplada del endpoint real (la integración llega en #285):
/// captura archivo o enlace + título, descripción y clasificación académica
/// en el orden oficial (Universidad, Carrera, Asignatura, Profesor, Año,
/// Tipo), valida 15 MB y formatos en el dispositivo y es desplazable con
/// teclado abierto en pantallas pequeñas.
class MaterialUploadScreen extends StatefulWidget {
  const MaterialUploadScreen({
    super.key,
    this.pickFile,
    this.onValidSubmit,
  });

  /// Seam para tests: reemplaza el selector nativo sin usar MethodChannels.
  final Future<MaterialPickedFile?> Function()? pickFile;

  /// Callback de maqueta tras validación OK (por defecto muestra SnackBar).
  /// En #285 se reemplaza por el envío multipart real.
  final void Function()? onValidSubmit;

  @override
  State<MaterialUploadScreen> createState() => _MaterialUploadScreenState();
}

class _MaterialUploadScreenState extends State<MaterialUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  _UploadSource _source = _UploadSource.file;
  MaterialPickedFile? _picked;
  bool _isPicking = false;
  String? _fileError;
  String? _formError;
  bool _submittedOk = false;

  final List<UniversityModel> _universities = UniversityModel.mockList();
  final List<CareerModel> _allCareers = CareerModel.mockList();
  final List<SubjectModel> _subjects = SubjectModel.mockList();
  final List<ProfessorModel> _professors = ProfessorModel.mockList();

  UniversityModel? _university;
  CareerModel? _career;
  SubjectModel? _subject;
  ProfessorModel? _professor;
  String? _typeCode;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _linkCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  List<CareerModel> get _visibleCareers {
    if (_university == null) return _allCareers;
    final filtered = _allCareers
        .where((c) => c.universityId == _university!.id)
        .toList();
    // Los mocks solo cubren UCT: si la universidad no tiene carreras
    // mockeadas se muestran todas para no bloquear la maqueta.
    return filtered.isEmpty ? _allCareers : filtered;
  }

  Future<void> _pickFile() async {
    setState(() {
      _isPicking = true;
      _fileError = null;
      _formError = null;
    });
    try {
      final MaterialPickedFile? picked;
      if (widget.pickFile != null) {
        picked = await widget.pickFile!();
      } else {
        picked = await _defaultPickFile();
      }
      if (!mounted) return;
      if (picked == null) return; // El usuario canceló el selector.
      final chosen = picked;
      setState(() {
        _picked = chosen;
        _fileError = MaterialUploadValidation.validatePickedFile(
          fileName: chosen.fileName,
          sizeBytes: chosen.sizeBytes,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fileError = 'No fue posible leer el archivo. Intenta de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  /// Selector nativo compatible con Android/iOS (file_picker 13).
  /// No lee los bytes en la maqueta: basta nombre y tamaño para validar
  /// (el multipart real llega en #285 y ahí se leerá el contenido).
  Future<MaterialPickedFile?> _defaultPickFile() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: MaterialUploadValidation.allowedExtensions,
    );
    if (f == null) return null;
    final size = f.lengthSync() ?? await f.length() ?? 0;
    return MaterialPickedFile(
      fileName: f.name,
      sizeBytes: size,
      mimeType: MaterialUploadValidation.mimeForExtension(
        MaterialUploadValidation.extensionOf(f.name),
      ),
      bytes: Uint8List(0),
    );
  }

  void _submit() {
    final fieldsOk = _formKey.currentState?.validate() ?? false;

    String? fileError;
    if (_source == _UploadSource.file) {
      if (_picked == null) {
        fileError = 'Selecciona un archivo.';
      } else {
        fileError = MaterialUploadValidation.validatePickedFile(
          fileName: _picked!.fileName,
          sizeBytes: _picked!.sizeBytes,
        );
      }
    }

    final cross = MaterialUploadValidation.validateTypeAgainstSource(
      typeCode: _typeCode,
      isFileSource: _source == _UploadSource.file,
    );

    setState(() {
      _fileError = fileError;
      _formError = cross;
      _submittedOk = false;
    });

    if (!fieldsOk || fileError != null || cross != null) return;

    setState(() => _submittedOk = true);
    if (widget.onValidSubmit != null) {
      widget.onValidSubmit!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maqueta: formulario válido. El envío real se conecta en #285.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir Material'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Comparte tus apuntes',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sube un archivo (PDF, Word o PowerPoint, máx. 15 MB) o '
                  'un enlace externo, con su clasificación académica.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FormErrorBanner(message: _formError),
                if (_submittedOk) _SuccessBanner(),
                const AppFieldLabel(label: 'Fuente del material'),
                const SizedBox(height: 6),
                SegmentedButton<_UploadSource>(
                  segments: const [
                    ButtonSegment(
                      value: _UploadSource.file,
                      label: Text('Archivo'),
                      icon: Icon(Icons.upload_file_outlined),
                    ),
                    ButtonSegment(
                      value: _UploadSource.link,
                      label: Text('Enlace'),
                      icon: Icon(Icons.link_outlined),
                    ),
                  ],
                  selected: {_source},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _source = selection.first;
                      _formError = null;
                    });
                    // Revalida el enlace (obligatorio ↔ opcional según fuente).
                    _formKey.currentState?.validate();
                  },
                ),
                const SizedBox(height: 16),
                if (_source == _UploadSource.file) ...[
                  OutlinedButton.icon(
                    onPressed: _isPicking ? null : _pickFile,
                    icon: _isPicking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open_outlined),
                    label: Text(
                      _picked == null
                          ? 'Seleccionar archivo (PDF, Word, PPT · máx. 15 MB)'
                          : 'Cambiar archivo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_picked != null)
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(
                          _picked!.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          MaterialUploadValidation.formatBytes(
                            _picked!.sizeBytes,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar archivo',
                          icon: const Icon(Icons.close_outlined),
                          onPressed: () => setState(() {
                            _picked = null;
                            _fileError = null;
                          }),
                        ),
                      ),
                    ),
                  if (_fileError != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fileError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  AppTextField(
                    controller: _linkCtrl,
                    label: 'Enlace externo',
                    hint: 'https://...',
                    icon: Icons.link_outlined,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        MaterialUploadValidation.validateExternalLink(
                      v,
                      required: true,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  controller: _titleCtrl,
                  label: 'Título',
                  hint: 'Guía de ejercicios resueltos',
                  icon: Icons.title_outlined,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  validator: MaterialUploadValidation.validateTitle,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descCtrl,
                  label: 'Descripción (opcional)',
                  hint: 'Qué contiene y a quién le sirve',
                  icon: Icons.description_outlined,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                Text(
                  'Clasificación académica',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'En el orden oficial: universidad, carrera, asignatura, '
                  'profesor, año y tipo.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UniversityModel>(
                  initialValue: _university,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Universidad',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: _universities
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (u) => setState(() {
                    _university = u;
                    // Si la carrera elegida no pertenece a la universidad,
                    // se limpia para no enviar una combinación inválida.
                    if (_career != null &&
                        u != null &&
                        _career!.universityId != u.id &&
                        !_visibleCareers.contains(_career)) {
                      _career = null;
                    }
                  }),
                  validator: (v) =>
                      v == null ? 'La universidad es obligatoria.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CareerModel>(
                  initialValue: _career,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Carrera',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: _visibleCareers
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (c) => setState(() => _career = c),
                  validator: (v) =>
                      v == null ? 'La carrera es obligatoria.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SubjectModel>(
                  initialValue: _subject,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Asignatura',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                  items: _subjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (s) => setState(() => _subject = s),
                  validator: (v) =>
                      v == null ? 'La asignatura es obligatoria.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ProfessorModel?>(
                  initialValue: _professor,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Profesor (opcional)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: [
                    const DropdownMenuItem<ProfessorModel?>(
                      value: null,
                      child: Text('Sin especificar'),
                    ),
                    ..._professors.map(
                      (p) => DropdownMenuItem<ProfessorModel?>(
                        value: p,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (p) => setState(() => _professor = p),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _yearCtrl,
                  label: 'Año',
                  hint: '2026',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  maxLength: 4,
                  validator: MaterialUploadValidation.validateYear,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _typeCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: MaterialUploadValidation.materialTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.code,
                          child: Text(t.label),
                        ),
                      )
                      .toList(),
                  onChanged: (t) => setState(() {
                    _typeCode = t;
                    _formError = null;
                  }),
                  validator: (v) =>
                      v == null ? 'El tipo es obligatorio.' : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'El tipo Enlace externo exige enlace y no admite archivo. '
                  'Los demás exigen archivo (máx. 15 MB).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_source == _UploadSource.file) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _linkCtrl,
                    label: 'Enlace de respaldo (opcional)',
                    hint: 'https://...',
                    icon: Icons.link_outlined,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        MaterialUploadValidation.validateExternalLink(
                      v,
                      required: false,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Subir material',
                  icon: Icons.cloud_upload_outlined,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                Text(
                  'Maqueta #280: valida en el dispositivo; '
                  'el envío real se conecta en #285.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                // Espacio extra para que el teclado no tape el botón
                // en pantallas pequeñas (320 × 568).
                SizedBox(
                  height: MediaQuery.viewInsetsOf(context).bottom > 0
                      ? 24
                      : 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Maqueta: formulario válido. El envío real se conecta en #285.',
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
