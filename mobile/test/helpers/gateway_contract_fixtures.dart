import 'gateway_test_transport.dart';

const universityId = '11111111-1111-4111-8111-111111111111';
const careerId = '22222222-2222-4222-8222-222222222222';
const subjectId = '33333333-3333-4333-8333-333333333333';
const professorId = '44444444-4444-4444-8444-444444444444';
const timestamp = '2026-10-30T12:00:00.000Z';

// Campos de los DTO públicos de Catalog, sin envolverlos en respuestas
// inventadas ni sustituir el repositorio por listas de modelos ya construidos.
final catalogResponses = <String, Object>{
  '$testGatewayUrl/catalog/universities': [
    {
      'id': universityId,
      'name': 'Universidad de prueba',
      'code': 'UNI',
      'active': true,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    },
  ],
  '$testGatewayUrl/catalog/careers?universityId=$universityId': [
    {
      'id': careerId,
      'universityId': universityId,
      'name': 'Informática',
      'code': 'INF',
      'active': true,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    },
  ],
  '$testGatewayUrl/catalog/subjects?careerId=$careerId': [
    {
      'id': subjectId,
      'careerId': careerId,
      'name': 'Redes',
      'code': 'INF-301',
      'semester': 3,
      'description': null,
      'active': true,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    },
  ],
  '$testGatewayUrl/catalog/professors?subjectId=$subjectId': [
    {
      'id': professorId,
      'name': 'Docente de prueba',
      'email': 'docente@example.test',
      'active': true,
    },
  ],
};

Map<String, dynamic> materialSummary(int number) => {
  'id': '55555555-5555-4555-8555-${number.toString().padLeft(12, '0')}',
  'title': 'Apunte $number',
  'description': null,
  'uploaderId': professorId,
  'academicOfferingId': null,
  'universityId': universityId,
  'careerId': careerId,
  'subjectId': subjectId,
  'professorId': null,
  'materialTypeId': '66666666-6666-4666-8666-666666666666',
  'materialType': 'DOCUMENT',
  'academicYear': 2026,
  'status': 'PUBLISHED',
  'verified': false,
  'createdAt': timestamp,
  'updatedAt': timestamp,
};

Map<String, dynamic> pageResponse(int page) => {
  'items': [
    for (var n = (page - 1) * 10 + 1; n <= (page == 1 ? 10 : 11); n++)
      materialSummary(n),
  ],
  'page': page,
  'pageSize': 10,
  'total': 11,
};

Map<String, dynamic> searchResponse({
  String? query = 'álgebra',
  int page = 1,
  int pageSize = 10,
  int total = 11,
}) => {
  'query': query,
  'page': page,
  'pageSize': pageSize,
  'total': total,
  'results': [
    for (
      var n = (page - 1) * pageSize + 1;
      n <= total && n <= page * pageSize;
      n++
    )
      {
        'id': materialSummary(n)['id'],
        'title': 'Apunte $n',
        'description': null,
        'materialType': 'DOCUMENT',
        'academicYear': 2026,
        'verified': false,
        'subjectId': subjectId,
        'careerId': careerId,
        'universityId': universityId,
        'professorId': professorId,
        'subjectName': 'Redes',
        'careerName': 'Informática',
        'universityName': 'Universidad de prueba',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      },
  ],
  'context': [
    {
      'subjectId': subjectId,
      'subjectName': 'Redes',
      'subjectCode': 'INF-301',
      'semester': 3,
      'careerId': careerId,
      'careerName': 'Informática',
      'universityId': universityId,
      'universityName': 'Universidad de prueba',
      'professors': [
        {'id': professorId, 'name': 'Docente de prueba'},
      ],
    },
  ],
};
