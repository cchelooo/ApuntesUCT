/// Validaciones de formulario compartidas por las pantallas de autenticación.
///
/// Cada método sigue la firma que espera `TextFormField.validator`: devuelve
/// `null` cuando el valor es válido y el mensaje de error cuando no lo es.
///
/// Viven en `core` y no dentro de cada pantalla para que Login y Registro
/// apliquen exactamente la misma regla al mismo campo. Duplicar la validación
/// fue el origen de la inconsistencia que corrige la tarea de pulido: el correo
/// se validaba distinto en cada formulario.
///
/// Estas reglas son una primera barrera de UX, no la fuente de verdad: el
/// backend valida de nuevo cada campo (RNF-01, la lógica de negocio no reside
/// en el cliente).
abstract final class Validators {
  /// Dominio del personal de la universidad.
  static const String staffDomain = 'uct.cl';

  /// Dominio del estudiantado.
  static const String alumniDomain = 'alu.uct.cl';

  /// Dominios institucionales habilitados para registrarse (RF-01).
  static const List<String> institutionalDomains = [staffDomain, alumniDomain];

  /// Nombre de usuario válido: letras, números, punto, guión y guión bajo, sin
  /// empezar ni terminar con un separador.
  static final RegExp _localPartPattern = RegExp(
    r'^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$',
    caseSensitive: false,
  );

  /// Marca de cuenta de estudiante: el año de admisión al final del usuario.
  static final RegExp _endsWithDigit = RegExp(r'\d$');

  /// Deduce el dominio institucional a partir del nombre de usuario.
  ///
  /// La convención de la universidad es que la cuenta de estudiante termina con
  /// el año de admisión (`jperez2020`) y la del personal no (`jperez`). De ahí
  /// la regla: **si termina en dígito, es del estudiantado.**
  ///
  /// Es una heurística sobre la convención, no un dato consultado a la
  /// universidad: una cuenta que se salga del patrón recibirá el dominio
  /// equivocado. El backend es el que valida de verdad (RNF-01), así que el
  /// costo de equivocarse es un rechazo al enviar, no una cuenta mal creada.
  static String institutionalDomainFor(String? localPart) {
    final normalized = (localPart ?? '').trim();
    return _endsWithDigit.hasMatch(normalized) ? alumniDomain : staffDomain;
  }

  /// Arma el correo completo a partir del nombre de usuario.
  ///
  /// Normaliza a minúsculas porque el usuario escribe en un teclado móvil con
  /// autocapitalización y el backend compara el correo tal cual llega.
  static String composeInstitutionalEmail(String? localPart) {
    final normalized = (localPart ?? '').trim().toLowerCase();
    return '$normalized@${institutionalDomainFor(normalized)}';
  }

  /// Valida el nombre de usuario, es decir la parte anterior al arroba.
  ///
  /// Es la única parte del correo que el usuario escribe: el dominio lo pone la
  /// app y no es editable, así que no hay nada que validar en él.
  static String? emailLocalPart(String? value) {
    final error = required(value, message: 'El correo es obligatorio.');
    if (error != null) return error;

    if (!_localPartPattern.hasMatch(value!.trim())) {
      return 'Usa sólo letras, números, punto, guión o guión bajo.';
    }
    return null;
  }

  /// Largo mínimo de contraseña exigido en el registro.
  static const int minPasswordLength = 8;

  /// Largo mínimo del nombre visible.
  static const int minNameLength = 3;

  /// Expresión razonablemente estricta para correo electrónico.
  ///
  /// No pretende cubrir el RFC 5322 completo: sólo descarta lo que claramente
  /// no es un correo antes de gastar una petición de red.
  static final RegExp _emailPattern = RegExp(
    r'^[\w.!#$%&*+/=?^`{|}~-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$',
  );

  /// Valida un campo obligatorio genérico.
  ///
  /// El mensaje se recibe completo en lugar de armarse con el nombre del campo:
  /// en español la concordancia de género cambia la frase ("el correo es
  /// obligatorio" pero "la contraseña es obligatoria"), y una plantilla única
  /// produce texto mal escrito en la mitad de los campos.
  static String? required(String? value, {required String message}) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  /// Valida el nombre visible del usuario.
  static String? name(String? value) {
    final error = required(value, message: 'El nombre es obligatorio.');
    if (error != null) return error;

    if (value!.trim().length < minNameLength) {
      return 'El nombre debe tener al menos $minNameLength caracteres.';
    }
    return null;
  }

  /// Valida el formato del correo. Se usa en Login, donde cualquier cuenta ya
  /// existente debe poder entrar aunque el dominio institucional cambie.
  static String? email(String? value) {
    final error = required(value, message: 'El correo es obligatorio.');
    if (error != null) return error;

    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Ingresa un correo válido.';
    }
    return null;
  }

  /// Valida que el correo sea institucional. Se usa en Registro (RF-01).
  static String? institutionalEmail(String? value) {
    final error = email(value);
    if (error != null) return error;

    final domain = value!.trim().toLowerCase().split('@').last;
    if (!institutionalDomains.contains(domain)) {
      return 'Usa tu correo institucional (${institutionalDomains.map((d) => '@$d').join(' o ')}).';
    }
    return null;
  }

  /// Valida la contraseña en Login: sólo se exige que venga.
  ///
  /// Aplicar aquí las reglas de robustez del registro bloquearía a cuentas
  /// creadas antes de que esas reglas existieran, y además revelaría la política
  /// de contraseñas a quien sólo está probando credenciales.
  static String? loginPassword(String? value) {
    return required(value, message: 'La contraseña es obligatoria.');
  }

  /// Valida la robustez de la contraseña en Registro.
  static String? newPassword(String? value) {
    final error = required(value, message: 'La contraseña es obligatoria.');
    if (error != null) return error;

    if (value!.length < minPasswordLength) {
      return 'Debe tener al menos $minPasswordLength caracteres.';
    }
    if (!value.contains(RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]'))) {
      return 'Debe incluir al menos una letra.';
    }
    if (!value.contains(RegExp(r'\d'))) {
      return 'Debe incluir al menos un número.';
    }
    return null;
  }

  /// Valida que la confirmación coincida con la contraseña ingresada.
  static String? passwordConfirmation(String? value, String password) {
    final error = required(value, message: 'La confirmación es obligatoria.');
    if (error != null) return error;

    if (value != password) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }
}
