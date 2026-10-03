-- CreateEnum
CREATE TYPE "ResourceType" AS ENUM ('SUMMARY', 'EXAM', 'GUIDE', 'CLASS_NOTES', 'OTHER');

-- CreateTable
CREATE TABLE "resources" (
    "id" TEXT NOT NULL,
    "subject_id" TEXT NOT NULL,
    "professor_id" TEXT,
    "title" TEXT NOT NULL,
    "file_url" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "type" "ResourceType" NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "resources_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "resources_subject_id_idx" ON "resources"("subject_id");

-- CreateIndex
CREATE INDEX "resources_year_type_idx" ON "resources"("year", "type");

-- AddForeignKey
ALTER TABLE "resources" ADD CONSTRAINT "resources_subject_id_fkey" FOREIGN KEY ("subject_id") REFERENCES "subjects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resources" ADD CONSTRAINT "resources_professor_id_fkey" FOREIGN KEY ("professor_id") REFERENCES "professors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
