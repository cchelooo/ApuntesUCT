-- Align Auth_User.id with the UUID type in the MER, preserving existing IDs.
-- Invalid UUID values abort the transaction without partially changing the schema.
BEGIN;

ALTER TABLE "refresh_tokens" DROP CONSTRAINT "refresh_tokens_user_id_fkey";

ALTER TABLE "users" ALTER COLUMN "id" TYPE UUID USING "id"::uuid;
ALTER TABLE "refresh_tokens" ALTER COLUMN "user_id" TYPE UUID USING "user_id"::uuid;

ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

COMMIT;
