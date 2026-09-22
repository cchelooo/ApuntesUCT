import { PrismaClient, ResourceType } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Iniciando seeding idempotente y compatible con datos preexistentes...');

  await prisma.$transaction(async (tx) => {
    // 1. Universidad (Clave única: code)
    const uct = await tx.university.upsert({
      where: { code: 'UCT' },
      update: {
        name: 'Universidad Católica de Temuco',
        active: true,
      },
      create: {
        name: 'Universidad Católica de Temuco',
        code: 'UCT',
        active: true,
      },
    });

    // 2. Carrera (Punto 1 Solicitado: Clave única compuesta universityId_code)
    const ici = await tx.career.upsert({
      where: {
        universityId_code: {
          universityId: uct.id,
          code: 'ICI',
        },
      },
      update: {
        name: 'Ingeniería Civil en Informática',
        active: true,
      },
      create: {
        name: 'Ingeniería Civil en Informática',
        code: 'ICI',
        active: true,
        universityId: uct.id,
      },
    });

    // 3. Profesor (Clave única: email)
    const professor = await tx.professor.upsert({
      where: { email: 'cramirez@uct.cl' },
      update: {
        name: 'Carlos Ramírez',
      },
      create: {
        name: 'Carlos Ramírez',
        email: 'cramirez@uct.cl',
      },
    });

    // 4. Asignatura (Punto 2 Solicitado: Clave única compuesta careerId_code)
    const dataStructures = await tx.subject.upsert({
      where: {
        careerId_code: {
          careerId: ici.id,
          code: 'ICI-314',
        },
      },
      update: {
        name: 'Estructuras de Datos',
        semester: 3,
        professors: {
          connect: { id: professor.id }, // Mantiene la relación con el profesor
        },
      },
      create: {
        name: 'Estructuras de Datos',
        code: 'ICI-314',
        semester: 3,
        careerId: ici.id,
        professors: {
          connect: { id: professor.id },
        },
      },
      include: {
        professors: true,
      },
    });

    // 5. Recurso (Punto 3 Solicitado: Detectar recurso preexistente para evitar duplicados)
    const existingResource = await tx.resource.findFirst({
      where: {
        subjectId: dataStructures.id,
        title: 'Certamen 1 - Algoritmos y Árboles',
      },
    });

    const resource = await tx.resource.upsert({
      where: {
        id: existingResource?.id ?? '00000000-0000-0000-0000-000000000000', // Reutiliza el ID si ya existía
      },
      update: {
        description: 'Evaluación parcial del primer semestre de Estructuras de Datos.',
        fileUrl: 'https://minio.local/materials/certamenes/c1-2026.pdf',
        type: ResourceType.EXAM,
        year: 2026,
        professorId: professor.id,
      },
      create: {
        title: 'Certamen 1 - Algoritmos y Árboles',
        description: 'Evaluación parcial del primer semestre de Estructuras de Datos.',
        fileUrl: 'https://minio.local/materials/certamenes/c1-2026.pdf',
        type: ResourceType.EXAM,
        year: 2026,
        subjectId: dataStructures.id,
        professorId: professor.id,
      },
    });

    console.log('✅ Seeding completado exitosamente sin duplicados:');
    console.log(` - Universidad: ${uct.name} (${uct.id})`);
    console.log(` - Carrera: ${ici.name} (${ici.id})`);
    console.log(` - Profesor: ${professor.name} (${professor.id})`);
    console.log(` - Asignatura: ${dataStructures.name} [Profesores: ${dataStructures.professors.length}]`);
    console.log(` - Recurso: ${resource.title} (${resource.id}) [Tipo: ${resource.type}, Año: ${resource.year}]`);
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