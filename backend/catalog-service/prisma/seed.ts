import { PrismaClient, ResourceType } from '@prisma/client';


const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Iniciando seeding completo para pruebas de integración...');

  // 1. Limpieza en orden por dependencias de Claves Foráneas
  await prisma.resource.deleteMany();
  await prisma.subject.deleteMany();
  await prisma.professor.deleteMany();
  await prisma.career.deleteMany();
  await prisma.university.deleteMany();

  // 2. Insertar Universidad
  const uct = await prisma.university.create({
    data: {
      name: 'Universidad Católica de Temuco',
      code: 'UCT',
    },
  });

  // 3. Insertar Carrera
  const ici = await prisma.career.create({
    data: {
      name: 'Ingeniería Civil en Informática',
      code: 'ICI',
      universityId: uct.id,
    },
  });

  // 4. Insertar Profesor
  const professor = await prisma.professor.create({
    data: {
      name: 'Carlos Ramírez',
      email: 'cramirez@uct.cl',
    },
  });

  // 5. Insertar Asignatura
  const dataStructures = await prisma.subject.create({
    data: {
      name: 'Estructuras de Datos',
      code: 'ICI-314',
      semester: 3,
      careerId: ici.id,
    },
  });

  // 6. Insertar Recurso con Año y Tipo de Recurso
  const resource = await prisma.resource.create({
    data: {
      title: 'Certamen 1 - Algoritmos y Árboles',
      description: 'Evaluación parcial del primer semestre de Estructuras de Datos.',
      fileUrl: 'https://minio.local/materials/certamenes/c1-2026.pdf',
      type: ResourceType.EXAM, // <-- Punto solicitado: TIPO (Enum/String)
      year: 2026,        // <-- Punto solicitado: AÑO
      subjectId: dataStructures.id,
      professorId: professor.id,
    },
  });

  console.log('✅ Seeding completado exitosamente:');
  console.log(` - Universidad: ${uct.name}`);
  console.log(` - Carrera: ${ici.name}`);
  console.log(` - Asignatura: ${dataStructures.name} (Semestre ${dataStructures.semester})`);
  console.log(` - Profesor: ${professor.name}`);
  console.log(` - Recurso: ${resource.title} [Tipo: ${resource.type}, Año: ${resource.year}]`);
}

main()
  .catch((e) => {
    console.error('❌ Error durante el seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });