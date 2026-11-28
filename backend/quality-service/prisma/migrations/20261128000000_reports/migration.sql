BEGIN;
-- No se eliminan ni se resuelven automáticamente reportes históricos duplicados.
-- Si existen, la creación del índice falla y exige conciliación explícita antes de desplegar.
ALTER TABLE "reports" ADD COLUMN "material_uploader_id" UUID, ADD COLUMN "resolution_note" TEXT;
CREATE UNIQUE INDEX "reports_one_open_per_user_material" ON "reports" ("user_id", "material_id") WHERE "status" IN ('OPEN', 'IN_REVIEW');
CREATE TABLE "report_mutations" (
 "id" UUID NOT NULL, "actor_id" UUID NOT NULL, "family" TEXT NOT NULL, "key" UUID NOT NULL,
 "fingerprint" TEXT NOT NULL, "response" JSONB NOT NULL, "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT "report_mutations_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "report_mutations_actor_id_family_key_key" ON "report_mutations" ("actor_id", "family", "key");
CREATE TABLE "report_history" (
 "id" UUID NOT NULL, "report_id" UUID NOT NULL, "actor_id" UUID NOT NULL,
 "previous_status" "ReportStatus", "status" "ReportStatus" NOT NULL, "resolution_note" TEXT,
 "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT "report_history_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "report_history_report_id_created_at_idx" ON "report_history" ("report_id", "created_at");
ALTER TABLE "reports" ADD CONSTRAINT "reports_reason_code" CHECK ("reason" IN ('INAPPROPRIATE_CONTENT','COPYRIGHT','INCORRECT_INFORMATION','BROKEN_RESOURCE','OTHER'));
COMMIT;
