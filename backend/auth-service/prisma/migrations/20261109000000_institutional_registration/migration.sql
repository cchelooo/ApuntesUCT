BEGIN;

-- Preserve accounts without automatically granting moderation privileges.
CREATE TYPE "Role_new" AS ENUM ('STUDENT', 'MODERATOR', 'ADMIN');
ALTER TABLE "users" ALTER COLUMN "role" DROP DEFAULT;
ALTER TABLE "users" ALTER COLUMN "role" TYPE "Role_new"
  USING (CASE WHEN "role"::text = 'PROFESSOR' THEN 'STUDENT' ELSE "role"::text END)::"Role_new";
DROP TYPE "Role";
ALTER TYPE "Role_new" RENAME TO "Role";
ALTER TABLE "users" ALTER COLUMN "role" SET DEFAULT 'STUDENT';

-- Existing collisions abort the transaction; never delete/merge accounts silently.
UPDATE "users" SET "email" = lower(btrim("email"));
ALTER TABLE "users" ADD CONSTRAINT "users_email_normalized"
  CHECK ("email" = lower(btrim("email")));

COMMIT;
