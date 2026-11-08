import '../domain/models/material_page.dart';

/// Valida SearchResponseDto antes de adaptar results al dominio de Material.
/// Una respuesta desconocida debe conservarse como error, no como lista vacía.
MaterialPage searchPageFromResponse(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw const FormatException('Search debe devolver un objeto JSON.');
  }
  _nullableText(data, const ['query']);
  final page = data['page'];
  final size = data['pageSize'];
  final total = data['total'];
  if (page is! int ||
      page < 1 ||
      page > 2147483647 ||
      size is! int ||
      size < 1 ||
      size > 100 ||
      total is! int ||
      total < 0 ||
      data['results'] is! List ||
      data['context'] is! List) {
    throw const FormatException('Metadatos de Search inválidos.');
  }
  for (final result in data['results'] as List) {
    if (result is! Map<String, dynamic> || result['verified'] is! bool) {
      throw const FormatException('Resultado de Search inválido.');
    }
    _requiredText(result, const ['id', 'title']);
    _nullableText(result, const [
      'description',
      'materialType',
      'subjectId',
      'careerId',
      'universityId',
      'professorId',
      'subjectName',
      'careerName',
      'universityName',
      'createdAt',
      'updatedAt',
    ]);
    final year = result['academicYear'];
    if (!result.containsKey('academicYear') ||
        (year != null && (year is! int || year < 1900 || year > 2099))) {
      throw const FormatException('Año académico de Search inválido.');
    }
    for (final field in ['createdAt', 'updatedAt']) {
      final value = result[field];
      if (value is String && DateTime.tryParse(value) == null) {
        throw FormatException('Fecha $field inválida.');
      }
    }
  }
  for (final context in data['context'] as List) {
    if (context is! Map<String, dynamic> || context['professors'] is! List) {
      throw const FormatException('Contexto de Search inválido.');
    }
    _requiredText(context, const ['subjectId', 'subjectName']);
    _nullableText(context, const [
      'subjectCode',
      'careerId',
      'careerName',
      'universityId',
      'universityName',
    ]);
    final semester = context['semester'];
    if (!context.containsKey('semester') ||
        (semester != null &&
            (semester is! int || semester < 1 || semester > 12))) {
      throw const FormatException('Semestre de Search inválido.');
    }
    for (final professor in context['professors'] as List) {
      if (professor is! Map<String, dynamic>) {
        throw const FormatException('Profesor de Search inválido.');
      }
      _requiredText(professor, const ['id', 'name']);
    }
  }
  return MaterialPage.fromJson({...data, 'items': data['results']});
}

void _nullableText(Map<String, dynamic> data, List<String> fields) {
  for (final field in fields) {
    if (!data.containsKey(field) ||
        (data[field] != null && data[field] is! String)) {
      throw FormatException('Campo $field ausente o inválido en Search.');
    }
  }
}

void _requiredText(Map<String, dynamic> data, List<String> fields) {
  for (final field in fields) {
    if (data[field] is! String || (data[field] as String).trim().isEmpty) {
      throw FormatException('Campo $field ausente o inválido en Search.');
    }
  }
}
