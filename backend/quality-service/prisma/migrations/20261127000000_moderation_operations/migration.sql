CREATE TYPE "ModerationOperationState" AS ENUM ('PENDING_APPLICATION','APPLIED','FAILED');
CREATE TABLE "moderation_operations" (
 "id" UUID PRIMARY KEY, "material_id" UUID NOT NULL, "actor_id" UUID NOT NULL,
 "actor_role" TEXT NOT NULL, "authorized_at" TIMESTAMPTZ(3) NOT NULL,
 "operation_family" TEXT NOT NULL DEFAULT 'moderation.decisions', "idempotency_key" UUID NOT NULL,
 "fingerprint" TEXT NOT NULL, "action" TEXT NOT NULL, "reason" TEXT,
 "expected_revision" INTEGER NOT NULL CHECK ("expected_revision" >= 1),
 "state" "ModerationOperationState" NOT NULL DEFAULT 'PENDING_APPLICATION',
 "snapshot" JSONB NOT NULL, "result" JSONB, "failure" JSONB,
 "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updated_at" TIMESTAMPTZ(3) NOT NULL,
 CONSTRAINT "moderation_action" CHECK ("action" IN ('APPROVE','REJECT')),
 CONSTRAINT "moderation_actor_role" CHECK ("actor_role" IN ('MODERATOR','ADMIN')),
 CONSTRAINT "moderation_reason" CHECK (("reason" IS NULL OR (length(btrim("reason")) BETWEEN 1 AND 2000)) AND ("action" <> 'REJECT' OR "reason" IS NOT NULL)),
 CONSTRAINT "moderation_outcome" CHECK (
 ("state"='PENDING_APPLICATION' AND "result" IS NULL AND "failure" IS NULL) OR
 ("state"='APPLIED' AND "result" IS NOT NULL AND "failure" IS NULL) OR
 ("state"='FAILED' AND "result" IS NULL AND "failure" IS NOT NULL))
);
CREATE UNIQUE INDEX "moderation_operations_actor_id_operation_family_idempotency_key" ON "moderation_operations"("actor_id","operation_family","idempotency_key");
ALTER TABLE "reviews" ADD COLUMN "operation_id" UUID;
CREATE UNIQUE INDEX "reviews_operation_id_key" ON "reviews"("operation_id");
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_operation_id_fkey" FOREIGN KEY ("operation_id") REFERENCES "moderation_operations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE TABLE "moderation_outbox" (
 "operation_id" UUID PRIMARY KEY, "attempts" INTEGER NOT NULL DEFAULT 0,
 "next_attempt_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
 "lease_until" TIMESTAMPTZ(3), "lease_token" UUID, "completed_at" TIMESTAMPTZ(3),
 CONSTRAINT "moderation_outbox_operation_id_fkey" FOREIGN KEY ("operation_id") REFERENCES "moderation_operations"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "moderation_outbox_completed_at_next_attempt_at_idx" ON "moderation_outbox"("completed_at","next_attempt_at");
