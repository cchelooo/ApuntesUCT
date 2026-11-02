export const academicIds = {
  university: '11111111-1111-4111-8111-111111111111',
  career: '22222222-2222-4222-8222-222222222222',
  subject: '33333333-3333-4333-8333-333333333333',
  professor: '44444444-4444-4444-8444-444444444444',
  other: '55555555-5555-4555-8555-555555555555',
  author: '66666666-6666-4666-8666-666666666666',
};

export const catalogTree = () => [
  {
    id: academicIds.university,
    name: 'Universidad de prueba',
    active: true,
    careers: [
      {
        id: academicIds.career,
        name: 'Carrera de prueba',
        active: true,
        subjects: [{ id: academicIds.subject, name: 'Asignatura de prueba', active: true }],
      },
    ],
  },
];

export const catalogProfessors = () => [
  {
    id: academicIds.professor,
    name: 'Profesor de prueba',
    email: 'profesor@example.com',
    active: true,
  },
];
