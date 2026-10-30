#!/usr/bin/env bash
# Orquestación de suites existentes; no contiene casos de prueba nuevos.
# Requiere npm ci, npm run build y la imagen MinIO del Dockerfile del repositorio.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root/backend"
log_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/apuntes-material-integration.XXXXXX")"
echo "Logs de integración: $log_dir"
postgres_name="apuntes-ci-postgres-$$"
minio_name="apuntes-ci-minio-$$"
catalog_pid=''

cleanup() {
  result=$?
  trap - EXIT
  set +e
  if [[ -n "$catalog_pid" ]]; then
    kill "$catalog_pid" 2>/dev/null
    wait "$catalog_pid" 2>/dev/null
  fi
  docker logs "$postgres_name" > "$log_dir/postgres.log" 2>&1
  docker logs "$minio_name" > "$log_dir/minio.log" 2>&1
  docker rm --force --volumes "$postgres_name" "$minio_name"
  cleanup_result=$?
  if [[ "$result" -eq 0 && "$cleanup_result" -ne 0 ]]; then
    result=$cleanup_result
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

docker run --detach --name "$postgres_name" \
  --publish 127.0.0.1::5432 \
  --env POSTGRES_USER=ci --env POSTGRES_PASSWORD=ci-disposable --env POSTGRES_DB=ci \
  postgres:17-alpine
docker run --detach --name "$minio_name" \
  --publish 127.0.0.1::9000 \
  --env MINIO_ROOT_USER=ci-minio --env MINIO_ROOT_PASSWORD=ci-minio-disposable \
  apuntesuct/pr-test-minio:local server /data

postgres_port="$(docker port "$postgres_name" 5432/tcp)"
postgres_port="${postgres_port##*:}"
export DATABASE_URL="postgresql://ci:ci-disposable@127.0.0.1:$postgres_port/ci?schema=public"
export MATERIAL_TEST_DATABASE_URL="$DATABASE_URL"
minio_port="$(docker port "$minio_name" 9000/tcp)"
export MINIO_ENDPOINT=127.0.0.1 MINIO_PORT="${minio_port##*:}" MINIO_USE_SSL=false
export MINIO_ACCESS_KEY=ci-minio MINIO_SECRET_KEY=ci-minio-disposable MINIO_BUCKET=ci-materials
# Habilitar todos los casos optativos existentes, incluido el recorrido por Gateway.
export MATERIAL_TEST_MINIO=1 MATERIAL_TEST_UPLOAD=1 MATERIAL_TEST_GATEWAY=1

for attempt in {1..30}; do
  if docker exec "$postgres_name" pg_isready -U ci -d ci; then break; fi
  if [[ "$attempt" -eq 30 ]]; then exit 1; fi
  sleep 2
done
node <<'NODE'
const { Client } = require('minio');
const client = new Client({
  endPoint: process.env.MINIO_ENDPOINT, port: Number(process.env.MINIO_PORT),
  useSSL: false, accessKey: process.env.MINIO_ACCESS_KEY, secretKey: process.env.MINIO_SECRET_KEY,
});
(async () => {
  for (let attempt = 0; attempt < 30; attempt++) {
    try {
      await client.listBuckets();
      await client.makeBucket(process.env.MINIO_BUCKET);
      return;
    } catch (error) {
      if (attempt === 29) throw error;
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
NODE

catalog_database_url="${DATABASE_URL%public}catalog"
DATABASE_URL="$catalog_database_url" npm run prisma:deploy --workspace=catalog-service
catalog_port="$(node -e 'const s=require("node:net").createServer(); s.listen(0,"127.0.0.1",()=>{console.log(s.address().port);s.close()})')"
export CATALOG_SERVICE_URL="http://127.0.0.1:$catalog_port/api/v1"
export MATERIAL_TEST_CATALOG_SERVICE_URL="$CATALOG_SERVICE_URL"
DATABASE_URL="$catalog_database_url" PORT="$catalog_port" \
  node catalog-service/dist/src/main.js > "$log_dir/catalog.log" 2>&1 &
catalog_pid=$!
export CI_CATALOG_HEALTH_URL="http://127.0.0.1:$catalog_port/health"
for attempt in {1..30}; do
  kill -0 "$catalog_pid"
  if node -e 'fetch(process.env.CI_CATALOG_HEALTH_URL,{signal:AbortSignal.timeout(2000)}).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))'; then break; fi
  if [[ "$attempt" -eq 30 ]]; then exit 1; fi
  sleep 2
done

# pipefail conserva el fallo del script oficial al guardar el TAP en el log.
timeout 300 npm run test:integration --workspace=material-service 2>&1 | tee "$log_dir/tests.log"
