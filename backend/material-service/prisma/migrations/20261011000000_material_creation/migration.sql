-- Los enlaces externos también se conservan cuando acompañan a un archivo.
ALTER TABLE "materials" ADD COLUMN "external_link" TEXT;

-- Códigos públicos del contrato POST. No reactivar tipos deshabilitados existentes.
INSERT INTO "material_types" ("id", "name", "active") VALUES
  (gen_random_uuid(), 'DOCUMENT', true),
  (gen_random_uuid(), 'PRESENTATION', true),
  (gen_random_uuid(), 'LINK', true),
  (gen_random_uuid(), 'EXAM', true),
  (gen_random_uuid(), 'SUMMARY', true)
ON CONFLICT ("name") DO NOTHING;
