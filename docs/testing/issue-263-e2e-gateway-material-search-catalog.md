# Evidencia E2E #263 - Gateway → Material/Search/Catalog (Flujo completo con servicios reales)

- Fecha: 2026-11-01
- Rama: feature/263-e2e-gateway-material-search-catalog
- Commit: 845d7c5df6652293e17797f7da6c7ddac5593a4d
- Gateway: http://localhost:3000 (todas las solicitudes deben pasar por el Gateway)
- Servicios involucrados: api-gateway (3000), auth-service (3001), catalog-service (3002), material-service (3003), search-service (3005), PostgreSQL, MinIO

## Pre-requisitos

1. Levantar infraestructura:
``bash
docker compose up -d
``
2. Instalar dependencias y generar Prisma (desde ackend/):
``bash
npm ci
npm run prisma:generate
``
3. Levantar servicios en terminales independientes desde ackend/:
``bash
# Terminal 1
cd api-gateway && npm run start:dev

# Terminal 2
cd auth-service && npm run prisma:generate && npm run start:dev

# Terminal 3
cd catalog-service && npm run prisma:generate && PORT=3002 npm run start:dev

# Terminal 4
cd material-service && npm run prisma:generate && npm run start:dev

# Terminal 5
cd search-service && npm run start:dev
``
4. Crear un archivo de prueba 	est.pdf en la raíz del repositorio.

## Comandos ejecutados (reproducibles)

### 1) Healthcheck vía Gateway
``bash
curl -i "http://localhost:3000/api/v1/health"
``
**Resultado:** Pendiente de ejecución con servicios reales levantados.

### 2) Login mock vía Gateway (obtener accessToken)
``bash
curl -i -X POST "http://localhost:3000/api/v1/auth/login" 
  -H "Content-Type: application/json" 
  -d '{"email":"estudiante@alu.uct.cl","password":"demo"}'
``
**Resultado:** Pendiente. Guardar ccessToken de la respuesta.

### 3) Consultar catálogo para obtener IDs
``bash
curl -i "http://localhost:3000/api/v1/catalog/universities"
curl -i "http://localhost:3000/api/v1/catalog/careers?universityId=<UNIVERSITY_ID>"
curl -i "http://localhost:3000/api/v1/catalog/subjects?careerId=<CAREER_ID>"
curl -i "http://localhost:3000/api/v1/catalog/professors?subjectId=<SUBJECT_ID>"
``
**Resultado:** Pendiente. Se utilizarán universityId, careerId, subjectId, professorId obtenidos.

### 4) Crear material (multipart) vía Gateway
``bash
curl -i -X POST "http://localhost:3000/api/v1/materials" 
  -H "Authorization: Bearer <ACCESS_TOKEN>" 
  -F "title=Apunte E2E #263" 
  -F "description=Prueba E2E completa Gateway->Material/Search/Catalog" 
  -F "materialType=APUNTE" 
  -F "academicYear=2026" 
  -F "universityId=<UNIVERSITY_ID>" 
  -F "careerId=<CAREER_ID>" 
  -F "subjectId=<SUBJECT_ID>" 
  -F "professorId=<PROFESSOR_ID>" 
  -F "file=@./test.pdf"
``
**Resultado:** Pendiente. Capturar id del material creado (<MATERIAL_ID>).

### 5) Listar y consultar material vía Gateway
``bash
curl -i "http://localhost:3000/api/v1/materials?page=1&pageSize=20" 
  -H "Authorization: Bearer <ACCESS_TOKEN>"

curl -i "http://localhost:3000/api/v1/materials/<MATERIAL_ID>" 
  -H "Authorization: Bearer <ACCESS_TOKEN>"
``
**Resultado:** Pendiente. Verificar presencia en listado y detalle correcto.

### 6) Descargar material vía Gateway
``bash
curl -i -L "http://localhost:3000/api/v1/materials/<MATERIAL_ID>/download" 
  -H "Authorization: Bearer <ACCESS_TOKEN>" 
  -o ./material-descargado-e2e-263.pdf
``
**Resultado:** Pendiente. Verificar status 200, Content-Type, Content-Disposition: attachment y archivo descargado.

### 7) Buscar material vía Gateway
``bash
curl -i "http://localhost:3000/api/v1/search?q=Apunte%20E2E%20%23263&page=1&pageSize=20&sortBy=createdAt&order=desc"
``
**Resultado:** Pendiente. Debe retornar el material creado con su contexto académico.

### 8) Consultar versiones vía Gateway
``bash
curl -i "http://localhost:3000/api/v1/materials/<MATERIAL_ID>" 
  -H "Authorization: Bearer <ACCESS_TOKEN>"
``
**Resultado:** Pendiente. Verificar que ersions contiene al menos la versión creada.

## Incidencias encontradas
- No se ejecutó en este entorno (servicios no levantados). Se deja evidencia reproducible con comandos y pasos para ejecución local con servicios reales.

## Conclusión
Se actualiza la evidencia con el formato correcto para acreditar el flujo completo exigido: todas las solicitudes pasan por http://localhost:3000, cubriendo Catalog → Auth → Material (crear/listar/detalle/descargar/versiones) → Search, sin acceso directo a microservicios.