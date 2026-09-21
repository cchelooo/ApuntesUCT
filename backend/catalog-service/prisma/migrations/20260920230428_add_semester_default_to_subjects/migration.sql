-- AlterTable
-- Paso 1: Agregar la columna permitiendo NULL temporalmente
ALTER TABLE "subjects" ADD COLUMN "semester" INTEGER;

-- Paso 2: Asignar el valor por defecto (1) a las asignaturas existentes con NULL
UPDATE "subjects" SET "semester" = 1 WHERE "semester" IS NULL;

-- Paso 3: Aplicar la restricción NOT NULL y el DEFAULT para futuras inserciones
ALTER TABLE "subjects" ALTER COLUMN "semester" SET NOT NULL;
ALTER TABLE "subjects" ALTER COLUMN "semester" SET DEFAULT 1;