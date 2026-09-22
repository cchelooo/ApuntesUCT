import { PrismaClient, ResourceType } from '@prisma/client';

const prisma = new PrismaClient();

// UUIDs estables para garantizar idempotencia y pruebas de integración repetibles
const SEED_IDS = {
  UNIVERSITY: '0a00e26a-7312-40e7-97cc-a7155431b34d',
  CAREER: 'b32137fd-86a6-4632-9e88-0ca70707a422',
  PROFESSOR: 'f87a912b-1111-42a1-9876-543210fedcba',
  SUBJECT: 'ce6574dd-bca2-49c3-a24c-518c82547af8',
  RESOURCE: 'd98234ea-3333-4bb3-8888-000000111222',
};

async function main() {
  console.log('🌱 Iniciando seeding atómico e idempotente para pruebas de integración...');

  await prisma.$transaction(async (tx) => {
    // 1. Upsert Universidad (Clave única: code)
    const uct = await tx.university.upsert({
      where: { code: 'UCT' },
      update: {
        name: 'Universidad Católica de Temuco',
        active: true,
      },
      create: {
        id: SEED_IDS.UNIVERSITY,
        name: 'Universidad Católica de Temuco',
        code: 'UCT',
        active: true,
      },
    });

    // 2. Upsert Carrera (Identificador estable)
    const ici = await tx.career.upsert({
      where: { id: SEED_IDS.CAREER },
      update: {
        name: 'Ingeniería Civil en Informática',
        code: 'ICI',
        active: true,
        universityId: uct.id,
      },
      create: {
        id: SEED_IDS.CAREER,
        name: 'Ingeniería Civil en Informática',
        code: 'ICI',
        active: true,
        universityId: uct.id,
      },
    });

    // 3. Upsert Profesor (Clave única: email)
    const professor = await tx.professor.upsert({
      where: { email: 'cramirez@uct.cl' },
      update: {
        name: 'Carlos Ramírez',
      },
      create: {
        id: SEED_IDS.PROFESSOR,
        name: 'Carlos Ramírez',
        email: 'cramirez@uct.cl',
      },
    });

    // 4. Upsert Asignatura (Conexión explícita con el Profesor)
    const dataStructures = await tx.subject.upsert({
      where: { id: SEED_IDS.SUBJECT },
      update: {
        name: 'Estructuras de Datos',
        code: 'ICI-314',
        semester: 3,
        careerId: ici.id,
        professors: {
          connect: { id: professor.id }, // Conexión implícita en N-N
        },
      },
      create: {
        id: SEED_IDS.SUBJECT,
        name: 'Estructuras de Datos',
        code: 'ICI-314',
        semester: 3,
        careerId: ici.id,
        professors: {
          connect: { id: professor.id }, // Conexión requerida para GET /catalog/filter
        },
      },
      include: {
        professors: true,
      },
    });

    // 5. Upsert Recurso (Identificador estable)
    const resource = await tx.resource.upsert({
      where: { id: SEED_IDS.RESOURCE },
      update: {
        title: 'Certamen 1 - Algoritmos y Árboles',
        description: 'Evaluación parcial del primer semestre de Estructuras de Datos.',
        fileUrl: 'https://minio.local/materials/certamenes/c1-2026.pdf',
        type: ResourceType.EXAM,
        year: 2026,
        subjectId: dataStructures.id,
        professorId: professor.id,
      },
      create: {
        id: SEED_IDS.RESOURCE,
        title: 'Certamen 1 - Algoritmos y Árboles',
        description: 'Evaluación parcial del primer semestre de Estructuras de Datos.',
        fileUrl: 'https://minio.local/materials/certamenes/c1-2026.pdf',
        type: ResourceType.EXAM,
        year: 2026,
        subjectId: dataStructures.id,
        professorId: professor.id,
      },
    });

    console.log('✅ Seeding completado exitosamente dentro de la transacción:');
    console.log(` - Universidad: ${uct.name} (${uct.id})`);
    console.log(` - Carrera: ${ici.name} (${ici.id})`);
    console.log(` - Profesor: ${professor.name} (${professor.id})`);
    console.log(` - Asignatura: ${dataStructures.name} [Profesores conectados: ${dataStructures.professors.length}]`);
    console.log(` - Recurso: ${resource.title} [Tipo: ${resource.type}, Año: ${resource.year}]`);
  });
}

main()
  .catch((e) => {
    console.error('❌ Error durante la ejecución del seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });