-- CreateEnum
CREATE TYPE "MaterialStatus" AS ENUM ('PENDING_REVIEW', 'PUBLISHED', 'REJECTED', 'WITHDRAWN');

-- CreateTable
CREATE TABLE "material_types" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "material_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "materials" (
    "id" UUID NOT NULL,
    "uploader_id" UUID NOT NULL,
    "academic_offering_id" TEXT,
    "university_id" TEXT,
    "career_id" TEXT,
    "subject_id" TEXT NOT NULL,
    "professor_id" TEXT,
    "material_type_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "academic_year" INTEGER NOT NULL,
    "status" "MaterialStatus" NOT NULL DEFAULT 'PENDING_REVIEW',
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "materials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "material_versions" (
    "id" UUID NOT NULL,
    "material_id" UUID NOT NULL,
    "version_number" INTEGER NOT NULL,
    "storage_key" TEXT NOT NULL,
    "original_filename" TEXT NOT NULL,
    "mime_type" TEXT NOT NULL,
    "file_size" BIGINT NOT NULL,
    "checksum" TEXT NOT NULL,
    "created_by" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "material_versions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "material_types_name_key" ON "material_types"("name");

-- CreateIndex
CREATE INDEX "materials_uploader_id_idx" ON "materials"("uploader_id");

-- CreateIndex
CREATE INDEX "materials_subject_id_status_idx" ON "materials"("subject_id", "status");

-- CreateIndex
CREATE INDEX "materials_professor_id_idx" ON "materials"("professor_id");

-- CreateIndex
CREATE INDEX "materials_material_type_id_idx" ON "materials"("material_type_id");

-- CreateIndex
CREATE UNIQUE INDEX "material_versions_material_id_version_number_key" ON "material_versions"("material_id", "version_number");

-- AddForeignKey
ALTER TABLE "materials" ADD CONSTRAINT "materials_material_type_id_fkey" FOREIGN KEY ("material_type_id") REFERENCES "material_types"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "material_versions" ADD CONSTRAINT "material_versions_material_id_fkey" FOREIGN KEY ("material_id") REFERENCES "materials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

