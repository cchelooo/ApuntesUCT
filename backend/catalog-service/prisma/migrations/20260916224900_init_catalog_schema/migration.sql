/*
  Warnings:

  - A unique constraint covering the columns `[university_id,code]` on the table `careers` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[career_id,code]` on the table `subjects` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `career_id` to the `subjects` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "subjects" ADD COLUMN     "career_id" TEXT NOT NULL;

-- CreateTable
CREATE TABLE "_ProfessorToSubject" (
    "A" TEXT NOT NULL,
    "B" TEXT NOT NULL,

    CONSTRAINT "_ProfessorToSubject_AB_pkey" PRIMARY KEY ("A","B")
);

-- CreateIndex
CREATE INDEX "_ProfessorToSubject_B_index" ON "_ProfessorToSubject"("B");

-- CreateIndex
CREATE UNIQUE INDEX "careers_university_id_code_key" ON "careers"("university_id", "code");

-- CreateIndex
CREATE INDEX "subjects_career_id_idx" ON "subjects"("career_id");

-- CreateIndex
CREATE UNIQUE INDEX "subjects_career_id_code_key" ON "subjects"("career_id", "code");

-- AddForeignKey
ALTER TABLE "subjects" ADD CONSTRAINT "subjects_career_id_fkey" FOREIGN KEY ("career_id") REFERENCES "careers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_ProfessorToSubject" ADD CONSTRAINT "_ProfessorToSubject_A_fkey" FOREIGN KEY ("A") REFERENCES "professors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_ProfessorToSubject" ADD CONSTRAINT "_ProfessorToSubject_B_fkey" FOREIGN KEY ("B") REFERENCES "subjects"("id") ON DELETE CASCADE ON UPDATE CASCADE;
