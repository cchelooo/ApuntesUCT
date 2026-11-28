ALTER TYPE "MaterialStatus" RENAME VALUE 'WITHDRAWN' TO 'RETIRED';
ALTER TABLE "materials" ADD COLUMN "revision" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "materials" ADD CONSTRAINT "materials_revision_positive" CHECK ("revision" >= 1);
CREATE TABLE "quality_decision_receipts" (
 "issuer_service" TEXT NOT NULL, "operation_id" UUID NOT NULL,
 "fingerprint" TEXT NOT NULL, "material_id" UUID NOT NULL, "actor_id" UUID NOT NULL,
 "http_status" INTEGER NOT NULL, "response" JSONB NOT NULL,
 "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY ("issuer_service", "operation_id")
);
