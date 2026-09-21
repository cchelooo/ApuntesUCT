import { exec } from 'child_process';
import { promisify } from 'util';
import { PrismaClient } from '@prisma/client';

const execAsync = promisify(exec);
const prisma = new PrismaClient();

describe('Prisma Migration - semester column', () => {
  beforeAll(async () => {
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('debe migrar asignaturas existentes asignando semester = 1 sin perder datos', async () => {
    const university = await prisma.university.create({
      data: {
        name: 'Universidad de Prueba',
        code: 'U-TEST',
      },
    });

    const career = await prisma.career.create({
      data: {
        name: 'Ingeniería de Prueba',
        code: 'ING-001',
        universityId: university.id,
      },
    });

    const subject = await prisma.subject.create({
      data: {
        name: 'Asignatura Existente',
        code: 'TEST-101',
        semester: 1,
        careerId: career.id,
      },
    });

    const { stderr } = await execAsync('npx prisma migrate deploy', {
      cwd: './catalog-service',
    });
    expect(stderr).not.toContain('P3018');

    const updatedSubject = await prisma.subject.findUnique({
      where: { id: subject.id },
    });

    expect(updatedSubject).toBeDefined();
    expect(updatedSubject?.name).toBe('Asignatura Existente');
    expect(updatedSubject?.semester).toBe(1);
  });
});