export const uuid = (value: number): string =>
  `00000000-0000-4000-8000-${String(value).padStart(12, '0')}`;

export const ids = {
  university: uuid(1),
  career: uuid(2),
  subject: uuid(3),
  professor: uuid(4),
  secondProfessor: uuid(5),
  otherUniversity: uuid(11),
  otherCareer: uuid(12),
  otherSubject: uuid(13),
  otherProfessor: uuid(14),
  missingSubject: uuid(99),
};

/** Respuesta de Material, independiente del DTO de Search. */
export interface PublishedMaterial {
  id: string;
  title: string;
  description: string | null;
  materialType: string;
  academicYear: number;
  verified: boolean;
  subjectId: string;
  careerId: string | null;
  universityId: string | null;
  professorId: string | null;
  createdAt: string;
  updatedAt: string;
  status: 'PUBLISHED';
}

export function material(
  index: number,
  overrides: Partial<PublishedMaterial> = {},
): PublishedMaterial {
  return {
    id: uuid(1000 + index),
    title: 'Álgebra lineal',
    description: null,
    materialType: 'DOCUMENT',
    academicYear: 2026,
    verified: false,
    subjectId: ids.subject,
    careerId: ids.career,
    universityId: ids.university,
    professorId: ids.professor,
    createdAt: '2026-10-03T00:00:00.000Z',
    updatedAt: '2026-10-03T00:00:00.000Z',
    status: 'PUBLISHED',
    ...overrides,
  };
}

export function materialsFixture(): PublishedMaterial[] {
  return [
    material(1),
    material(2, {
      title: 'Árboles y grafos',
      description: 'Aplicaciones del álgebra',
      professorId: ids.secondProfessor,
      academicYear: 2025,
      materialType: 'SUMMARY',
      createdAt: '2026-10-02T00:00:00.000Z',
    }),
    material(3),
    material(4, {
      title: 'Biología',
      materialType: 'LINK',
      subjectId: ids.otherSubject,
      careerId: ids.otherCareer,
      universityId: ids.otherUniversity,
      professorId: ids.otherProfessor,
      createdAt: '2026-10-04T00:00:00.000Z',
    }),
    material(5, {
      title: 'Zoología',
      professorId: null,
      academicYear: 2024,
      materialType: 'APUNTE',
      createdAt: '2026-10-05T00:00:00.000Z',
    }),
    material(6, {
      title: 'Sin contexto',
      subjectId: ids.missingSubject,
      careerId: null,
      universityId: null,
      professorId: null,
      createdAt: '2026-10-06T00:00:00.000Z',
    }),
    material(7, {
      title: 'Contexto contradictorio',
      universityId: ids.otherUniversity,
      createdAt: '2026-10-07T00:00:00.000Z',
    }),
  ];
}

export function catalogFixture() {
  return [
    {
      id: ids.subject,
      name: 'Matemáticas',
      code: 'MAT-01',
      semester: 1,
      career: {
        id: ids.career,
        name: 'Informática',
        university: { id: ids.university, name: 'Universidad Uno' },
      },
      professors: [
        { id: ids.professor, name: 'Profesora Uno' },
        { id: ids.secondProfessor, name: 'Profesor Dos' },
      ],
    },
    {
      id: ids.otherSubject,
      name: 'Biología',
      code: 'BIO-01',
      semester: 2,
      career: {
        id: ids.otherCareer,
        name: 'Biología',
        university: { id: ids.otherUniversity, name: 'Universidad Dos' },
      },
      professors: [{ id: ids.otherProfessor, name: 'Profesora Tres' }],
    },
  ];
}
