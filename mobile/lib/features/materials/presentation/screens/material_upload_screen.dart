import 'package:apuntesuct_mobile/core/widgets/app_primary_button.dart';
import 'package:apuntesuct_mobile/core/widgets/app_text_field.dart';
import 'package:apuntesuct_mobile/core/widgets/form_error_banner.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_catalog_selectors_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_upload_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _UploadSource { file, link }

/// Formulario de subida de material (issues #280 y #285).
///
/// Captura archivo o enlace + título, descripción y clasificación académica
/// en el orden oficial (Universidad, Carrera, Asignatura, Profesor, Año,
/// Tipo), valida 15 MB y formatos en el dispositivo y envía multipart real
/// a POST /materials vía [materialUploadProvider]. Es desplazable con
/// teclado abierto en pantallas pequeñas.
class MaterialUploadScreen extends ConsumerStatefulWidget {
  const MaterialUploadScreen({super.key, this.pickFile});

  /// Seam para tests: reemplaza el selector nativo sin usar MethodChannels.
  final Future<MaterialPickedFile?> Function()? pickFile;

  @override
  ConsumerState<MaterialUploadScreen> createState() =>
      _MaterialUploadScreenState();
}

class _MaterialUploadScreenState extends ConsumerState<MaterialUploadScreen> {
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

  /// Request de la subida confirmada: la confirmación muestra sus nombres
  /// académicos y fuente, porque el 201 solo trae IDs (sin nombres) y la
  /// descarga aún no existe (el detalle remoto solo sirve PUBLISHED).
  UploadMaterialRequest? _lastRequest;

  UniversityModel? _university;
  CareerModel? _career;
  SubjectModel? _subject;
  ProfessorModel? _professor;
  String? _typeCode;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _linkCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
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
  ///
  /// Lee los bytes reales para el multipart de #285. Si el tamaño ya
  /// excede el límite no se lee el contenido: la validación lo rechaza.
  /// Un fallo de lectura lanza y [_pickFile] lo convierte en [_fileError].
  Future<MaterialPickedFile?> _defaultPickFile() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: MaterialUploadValidation.allowedExtensions,
    );
    if (f == null) return null;
    final size = f.lengthSync() ?? await f.length() ?? 0;
    final mimeType = MaterialUploadValidation.mimeForExtension(
      MaterialUploadValidation.extensionOf(f.name),
    );
    if (size > MaterialUploadValidation.maxFileSizeBytes ||
        !MaterialUploadValidation.allowedExtensions.contains(
          MaterialUploadValidation.extensionOf(f.name),
        )) {
      return MaterialPickedFile(
        fileName: f.name,
        sizeBytes: size,
        mimeType: mimeType,
      );
    }
    final bytes = await f.readAsBytes();
    return MaterialPickedFile(
      fileName: f.name,
      sizeBytes: bytes.length,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  Future<void> _submit() async {
    final fieldsOk = _formKey.currentState?.validate() ?? false;

    String? fileError;
    if (_source == _UploadSource.file) {
      if (_picked == null) {
        fileError = 'Selecciona un archivo.';
      } else if (_picked!.bytes.isEmpty) {
        fileError = 'No fue posible leer el archivo. Intenta de nuevo.';
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

    final university = _university;
    final career = _career;
    final subject = _subject;
    final typeCode = _typeCode;
    if (university == null ||
        career == null ||
        subject == null ||
        typeCode == null) {
      return;
    }

    final linkText = _linkCtrl.text.trim();
    final request = UploadMaterialRequest(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      university: AcademicReference(id: university.id, name: university.name),
      career: AcademicReference(id: career.id, name: career.name),
      subject: AcademicReference(id: subject.id, name: subject.name),
      professor: _professor == null
          ? null
          : AcademicReference(id: _professor!.id, name: _professor!.name),
      year: int.parse(_yearCtrl.text.trim()),
      type: typeCode,
      source: _source == _UploadSource.file
          ? LocalMaterialFile(
              fileName: _picked!.fileName,
              mimeType: _picked!.mimeType,
              bytes: _picked!.bytes,
            )
          : ExternalMaterialLink(Uri.parse(linkText)),
      backupLink: _source == _UploadSource.file && linkText.isNotEmpty
          ? Uri.tryParse(linkText)
          : null,
    );

    final ok = await ref.read(materialUploadProvider.notifier).upload(request);
    if (!mounted) return;
    if (ok) {
      // Éxito confirmado: se guarda la fuente enviada para mostrarla y
      // se limpia el formulario. Ante un error no se limpia nada.
      _handleSuccess(request);
    } else {
      setState(() => _submittedOk = false);
    }
    await _scrollToTop();
  }

  /// Limpia solo los campos del formulario (sin tocar el provider).
  void _clearFields() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _linkCtrl.clear();
    _yearCtrl.clear();
    _formKey.currentState?.reset();
    setState(() {
      _source = _UploadSource.file;
      _picked = null;
      _isPicking = false;
      _fileError = null;
      _formError = null;
      _university = null;
      _career = null;
      _subject = null;
      _professor = null;
      _typeCode = null;
    });
  }

  void _handleSuccess(UploadMaterialRequest request) {
    _clearFields();
    setState(() {
      _lastRequest = request;
      _submittedOk = true;
    });
  }

  final _scrollCtrl = ScrollController();

  Future<void> _scrollToTop() async {
    if (!_scrollCtrl.hasClients) return;
    await _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Vuelve al formulario vacío tras un éxito (o descarta el estado).
  void _resetForm() {
    _clearFields();
    ref.read(materialUploadProvider.notifier).reset();
    setState(() {
      _submittedOk = false;
      _lastRequest = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(materialUploadProvider);
    // Selectores con UUID reales de Catalog (#287): cada nivel depende del
    // anterior y con padre nulo resuelven `[]` sin red (dropdown deshabilitado).
    // Se usa hasError/isLoading + pattern matching en vez de `when`: un refresh
    // fallido queda como AsyncLoading con el error adjunto y `when` lo
    // trataría como carga, ocultando el mensaje y el reintento.
    final universities = ref.watch(uploadUniversitiesProvider);
    final universityItems = switch (universities) {
      AsyncData(:final value) => value,
      _ => const <UniversityModel>[],
    };
    final careers = ref.watch(uploadCareersProvider(_university?.id));
    final careerItems = switch (careers) {
      AsyncData(:final value) => value,
      _ => const <CareerModel>[],
    };
    final subjects = ref.watch(uploadSubjectsProvider(_career?.id));
    final subjectItems = switch (subjects) {
      AsyncData(:final value) => value,
      _ => const <SubjectModel>[],
    };
    final professors = ref.watch(uploadProfessorsProvider(_subject?.id));
    final professorItems = switch (professors) {
      AsyncData(:final value) => value,
      _ => const <ProfessorModel>[],
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Subir Material'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _submittedOk && upload.created != null && _lastRequest != null
              // Confirmación de subida aceptada: muestra el detalle
              // devuelto por el 201 en vez del formulario (ya limpio).
              ? _UploadSuccessView(
                  created: upload.created!,
                  request: _lastRequest!,
                  onHome: () => context.go('/'),
                  onAgain: _resetForm,
                )
              : Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Comparte tus apuntes',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sube un archivo (PDF, Word o PowerPoint, máx. 15 MB) o '
                        'un enlace externo, con su clasificación académica.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      FormErrorBanner(
                        message: _formError ?? upload.errorMessage,
                      ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'En el orden oficial: universidad, carrera, asignatura, '
                        'profesor, año y tipo.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<UniversityModel>(
                        // La key incluye hasValue para descartar un error de carga
                        // obsoleto cuando el reintento trae datos.
                        key: ValueKey(
                          'upload-university-${universities.hasValue}',
                        ),
                        initialValue: _university,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Universidad',
                          prefixIcon: const Icon(
                            Icons.account_balance_outlined,
                          ),
                          helperText: universities.hasError
                              ? 'No se pudieron cargar las universidades.'
                              : universities.isLoading
                              ? 'Cargando universidades…'
                              : null,
                          helperMaxLines: 2,
                        ),
                        items: universityItems
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
                        onChanged:
                            universities.hasError || universityItems.isEmpty
                            ? null
                            : (u) {
                                if (u?.id == _university?.id) return;
                                setState(() {
                                  // Todo lo elegido bajo otra universidad queda
                                  // obsoleto.
                                  _university = u;
                                  _career = null;
                                  _subject = null;
                                  _professor = null;
                                });
                              },
                        // El error de carga también va en el validador: una vez que
                        // el formulario valida, el errorText oculta el helperText.
                        validator: (v) {
                          if (universities.hasError) {
                            return 'No se pudieron cargar las universidades.';
                          }
                          return v == null
                              ? 'La universidad es obligatoria.'
                              : null;
                        },
                      ),
                      if (universities.hasError) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                ref.invalidate(uploadUniversitiesProvider),
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('Reintentar'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<CareerModel>(
                        // Sin `value:` en Flutter 3.47 (solo initialValue): la key
                        // fuerza el reseteo visual cuando la cascada limpia.
                        key: ValueKey(
                          'upload-career-${_university?.id}-${careers.hasValue}',
                        ),
                        initialValue: _career,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Carrera',
                          prefixIcon: const Icon(Icons.school_outlined),
                          helperText: _university == null
                              ? 'Selecciona una universidad.'
                              : careers.hasError
                              ? 'No se pudieron cargar las carreras.'
                              : careers.isLoading
                              ? 'Cargando carreras…'
                              : careerItems.isEmpty
                              ? 'No hay carreras disponibles para esta universidad.'
                              : null,
                          helperMaxLines: 2,
                        ),
                        items: careerItems
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
                        onChanged:
                            _university == null ||
                                careers.hasError ||
                                careers.isLoading ||
                                careerItems.isEmpty
                            ? null
                            : (c) {
                                if (c?.id == _career?.id) return;
                                setState(() {
                                  _career = c;
                                  _subject = null;
                                  _professor = null;
                                });
                              },
                        validator: (v) {
                          if (careers.hasError) {
                            return 'No se pudieron cargar las carreras.';
                          }
                          return v == null
                              ? 'La carrera es obligatoria.'
                              : null;
                        },
                      ),
                      if (careers.hasError && _university != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => ref.invalidate(
                              uploadCareersProvider(_university?.id),
                            ),
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('Reintentar'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SubjectModel>(
                        key: ValueKey(
                          'upload-subject-${_university?.id}-${_career?.id}-'
                          '${subjects.hasValue}',
                        ),
                        initialValue: _subject,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Asignatura',
                          prefixIcon: const Icon(Icons.book_outlined),
                          helperText: _career == null
                              ? 'Selecciona una carrera.'
                              : subjects.hasError
                              ? 'No se pudieron cargar las asignaturas.'
                              : subjects.isLoading
                              ? 'Cargando asignaturas…'
                              : subjectItems.isEmpty
                              ? 'No hay asignaturas disponibles para esta carrera.'
                              : null,
                          helperMaxLines: 2,
                        ),
                        items: subjectItems
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
                        onChanged:
                            _career == null ||
                                subjects.hasError ||
                                subjects.isLoading ||
                                subjectItems.isEmpty
                            ? null
                            : (s) {
                                if (s?.id == _subject?.id) return;
                                setState(() {
                                  _subject = s;
                                  _professor = null;
                                });
                              },
                        validator: (v) {
                          if (subjects.hasError) {
                            return 'No se pudieron cargar las asignaturas.';
                          }
                          return v == null
                              ? 'La asignatura es obligatoria.'
                              : null;
                        },
                      ),
                      if (subjects.hasError && _career != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => ref.invalidate(
                              uploadSubjectsProvider(_career?.id),
                            ),
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('Reintentar'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ProfessorModel?>(
                        key: ValueKey(
                          'upload-professor-${_university?.id}-${_career?.id}-${_subject?.id}',
                        ),
                        initialValue: _professor,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Profesor (opcional)',
                          prefixIcon: const Icon(Icons.person_outline),
                          helperText: _subject == null
                              ? null
                              : professors.hasError
                              ? 'No se pudieron cargar los profesores.'
                              : professors.isLoading
                              ? 'Cargando profesores…'
                              : null,
                          helperMaxLines: 2,
                        ),
                        items: [
                          const DropdownMenuItem<ProfessorModel?>(
                            value: null,
                            child: Text('Sin especificar'),
                          ),
                          ...professorItems.map(
                            (p) => DropdownMenuItem<ProfessorModel?>(
                              value: p,
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged:
                            _subject == null ||
                                professors.hasError ||
                                professors.isLoading
                            ? null
                            : (p) => setState(() => _professor = p),
                      ),
                      if (professors.hasError && _subject != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => ref.invalidate(
                              uploadProfessorsProvider(_subject?.id),
                            ),
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('Reintentar'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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
                        label: upload.isUploading
                            ? 'Subiendo…'
                            : 'Subir material',
                        icon: Icons.cloud_upload_outlined,
                        isLoading: upload.isUploading,
                        onPressed: upload.isUploading ? null : _submit,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'El material queda en revisión tras el envío '
                        'a Material Service.',
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

String _typeLabel(String code) {
  for (final t in MaterialUploadValidation.materialTypes) {
    if (t.code == code) return t.label;
  }
  return code;
}

/// Confirmación de subida aceptada: informa que el material fue recibido y
/// representa su estado inicial PENDING_REVIEW sin afirmar publicación.
///
/// Muestra el detalle devuelto por el 201 (el GET :id solo sirve materiales
/// PUBLISHED, por eso no se navega al detalle remoto todavía) y ofrece
/// volver al inicio o subir otro material. El formulario ya quedó limpio.
class _UploadSuccessView extends StatelessWidget {
  const _UploadSuccessView({
    required this.created,
    required this.request,
    required this.onHome,
    required this.onAgain,
  });

  final MaterialDetail created;
  final UploadMaterialRequest request;
  final VoidCallback onHome;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = created.summary;

    // Nombres del request enviado: el 201 solo trae IDs (H1).
    final sourceLine = switch (request.source) {
      LocalMaterialFile f =>
        'Archivo · ${f.fileName} · '
            '${MaterialUploadValidation.formatBytes(f.bytes.length)}',
      ExternalMaterialLink l => 'Enlace · ${l.url}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Icon(Icons.check_circle, size: 64, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          '¡Material recibido!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Tu material fue registrado correctamente y quedó en revisión.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.hourglass_top_outlined,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.reviewStatus.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      'Estado: ${summary.status}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Todavía no es visible en el catálogo: '
          'aparecerá cuando pase la revisión.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailRow(label: 'Título', value: summary.title),
                _DetailRow(
                  label: 'Tipo',
                  value: _typeLabel(summary.materialType),
                ),
                if (summary.academicYear != null)
                  _DetailRow(
                    label: 'Año',
                    value: summary.academicYear.toString(),
                  ),
                _DetailRow(
                  label: 'Asignatura',
                  value: request.subject.name ?? request.subject.id,
                ),
                _DetailRow(label: 'Fuente', value: sourceLine),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppPrimaryButton(
          label: 'Volver al inicio',
          icon: Icons.home_outlined,
          onPressed: onHome,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onAgain,
          icon: const Icon(Icons.add_outlined),
          label: const Text('Subir otro material'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
