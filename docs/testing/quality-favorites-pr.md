# Implementar favoritos propios en Quality Service

Permite guardar, listar y eliminar favoritos mediante tres endpoints del contrato S3-04. Cada operación usa la identidad vigente del usuario; ningún rol puede modificar favoritos ajenos. Agregar exige material publicado y conserva id/createdAt al repetir. La lista incluye referencias no disponibles sin revelar metadatos privados. Eliminar es idempotente y no depende de Material.

- Paginación coherente, orden determinista y verificación de disponibilidad limitada a la página con concurrencia acotada.
- Restricción única existente y serialización de PUT/DELETE concurrentes.
- Errores de autorización, entrada y dependencias; ningún fallo se interpreta como available=false.
- Integración REST con Auth y Material, sin SQL a bases ajenas ni cambios en Material.
- Reutiliza Favorite: no hay migración nueva de Quality.
- Incluye el requisito compartido de identidad actual/tokenVersion de Auth y proxy Quality, para funcionar desde main sin los otros PR. Conservar una sola copia al combinar ramas.
- Pruebas PostgreSQL/HTTP y trabajo CI de favoritos.

## Validación

Ver quality-favorites-validation.md. Actualizar la evidencia con los resultados de la rama y commit probado antes de enviar. Los checks remotos y la revisión del equipo siguen pendientes.

## Configuración y despliegue

QUALITY_FAVORITES_AUTH_URL y QUALITY_FAVORITES_MATERIAL_URL en Quality; QUALITY_SERVICE_URL en Gateway. Auth necesita la migración 20261127000000_access_token_version (idéntica a la incluida en los otros paquetes). No duplicarla ni renombrarla. No incluir .env ni claves en el PR.

La integración usa LINK y no prueba MinIO/UI. La funcionalidad no publica ni retira materiales.
