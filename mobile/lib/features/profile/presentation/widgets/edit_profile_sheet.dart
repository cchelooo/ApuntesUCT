import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/uct_palette.dart';
import '../providers/profile_provider.dart';

/// Modal interactivo para editar los datos del perfil de usuario.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  /// Muestra el modal de edición de perfil configurado para adaptarse al teclado.
  static Future<void> show(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const EditProfileSheet(),
    );
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _careerController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileDataProvider);
    _nameController = TextEditingController(text: profile.name);
    _careerController = TextEditingController(text: profile.career);
    _bioController = TextEditingController(text: profile.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _careerController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    ref
        .read(profileDataProvider.notifier)
        .updateProfile(
          name: _nameController.text.trim(),
          career: _careerController.text.trim(),
          bio: _bioController.text.trim(),
        );

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Perfil actualizado correctamente'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    final colorFondoCampo = esOscuro
        ? UctPalette.superficieElevadaOscura
        : UctPalette.humo;
    final colorBordeCampo = esOscuro
        ? UctPalette.bordeOscuro
        : UctPalette.bordeClaro;
    final colorBotonPrimario = esOscuro ? UctPalette.amarillo : UctPalette.azul;
    final colorTextoBotonPrimario = esOscuro ? UctPalette.navy : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Indicador de arrastre superior
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: esOscuro
                          ? UctPalette.bordeOscuro
                          : Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Encabezado del modal
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: esOscuro
                            ? UctPalette.superficieElevadaOscura
                            : const Color(0xFFEAF3FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: esOscuro ? UctPalette.amarillo : UctPalette.azul,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Editar Perfil',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Campo: Nombre completo
                Text(
                  'Nombre completo',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Ej. Marcelo Santana',
                    filled: true,
                    fillColor: colorFondoCampo,
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: esOscuro
                          ? UctPalette.textoSuaveOscuro
                          : UctPalette.textoSuaveClaro,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBordeCampo),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBordeCampo),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: esOscuro ? UctPalette.amarillo : UctPalette.azul,
                        width: 1.8,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa tu nombre';
                    }
                    if (value.trim().length < 3) {
                      return 'El nombre debe tener al menos 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo: Carrera
                Text(
                  'Carrera o programa',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _careerController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Ej. Ingeniería Civil Informática',
                    filled: true,
                    fillColor: colorFondoCampo,
                    prefixIcon: Icon(
                      Icons.school_outlined,
                      color: esOscuro
                          ? UctPalette.textoSuaveOscuro
                          : UctPalette.textoSuaveClaro,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBordeCampo),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBordeCampo),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: esOscuro ? UctPalette.amarillo : UctPalette.azul,
                        width: 1.8,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa tu carrera';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo: Biografía
                Text(
                  'Biografía y presentación',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 200,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cuéntale a la comunidad sobre tus intereses o ramos...',
                    filled: true,
                    fillColor: colorFondoCampo,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBordeCampo),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorBordeCampo),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: esOscuro ? UctPalette.amarillo : UctPalette.azul,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          side: BorderSide(color: colorBordeCampo),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: colorBotonPrimario,
                          foregroundColor: colorTextoBotonPrimario,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Guardar cambios',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
