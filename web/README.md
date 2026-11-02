# React + TypeScript + Vite

## Estilos y compatibilidad

La web utiliza Tailwind CSS 4.3 mediante `@tailwindcss/vite`. Los colores y
fuentes se mantienen en `tailwind.config.js`, cargado desde `src/index.css`.
La paleta clara proviene de `mobile/lib/core/theme/uct_palette.dart`.

Navegadores mínimos: Safari 16.4, Chrome 111 y Firefox 128. Véase la
[guía de migración de Tailwind](https://tailwindcss.com/docs/upgrade-guide).
Después de actualizar dependencias hay que reiniciar `npm run dev`.

## Pruebas

Ejecuta las pruebas en modo interactivo con `npm test` o una sola vez con `npm run test:run`.

## Formulario de material (#224)

La ruta `/materials/upload`, accesible desde **Subir material**, permite
completar título, descripción, universidad, carrera, asignatura, profesor,
año y tipo. Reutiliza los selectores académicos en cascada y los componentes
Input, Select y Button. Los datos académicos se consultan mediante el API
Gateway configurado en `VITE_API_URL`.

Para documentos, presentaciones, evaluaciones y resúmenes se selecciona un
archivo; para el tipo Enlace se muestra una URL. El selector informa los
formatos PDF, Word y PowerPoint y el límite de 15 MB del contrato backend.
Cambiar entre archivo y enlace limpia el adjunto anterior.

**Revisar material** muestra un resumen editable antes de confirmar. Al
seleccionar **Subir material**, el formulario envía los metadatos y el archivo
como `multipart/form-data` mediante `POST /api/v1/materials`; Material Service
valida y persiste la solicitud. Una creación exitosa queda en estado
`PENDING_REVIEW`, por lo que no aparece inmediatamente en las vistas públicas
que solo muestran materiales publicados. En desarrollo, la subida necesita el
contexto local de autor de Material Service habilitado; el login mock no
autoriza esta operación.

La vista usa la paleta clara de mobile: azul para acciones, amarillo como
acento, fondos blancos/celestes y controles de 54 px. En celular los campos
se apilan; desde 640 px se agrupan en dos columnas y desde 1024 px los
consejos se ubican junto al formulario.

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

```js
export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...

      // Remove tseslint.configs.recommended and replace with this
      tseslint.configs.recommendedTypeChecked,
      // Alternatively, use this for stricter rules
      tseslint.configs.strictTypeChecked,
      // Optionally, add this for stylistic rules
      tseslint.configs.stylisticTypeChecked,

      // Other configs...
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
]);
```

You can also install [eslint-plugin-react-x](https://npmx.dev/package/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://npmx.dev/package/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from 'eslint-plugin-react-x';
import reactDom from 'eslint-plugin-react-dom';

export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...
      // Enable lint rules for React
      reactX.configs['recommended-typescript'],
      // Enable lint rules for React DOM
      reactDom.configs.recommended,
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
]);
```

## Cliente de Material (#223)

`VITE_API_URL` debe apuntar al API Gateway (por ejemplo,
`http://localhost:3000/api/v1`). Es obligatoria para todas las llamadas
públicas de la web; si falta o está vacía, la solicitud falla explícitamente
en vez de usar un origen alternativo.

- `fetchMaterials(params, signal)` conserva el mapeo del listado para la UI,
  incluyendo `totalPages`, y permite cancelar solicitudes con TanStack Query.
  El contrato HTTP de listado está en `domain/material/materialApi.ts`; el
  modelo de presentación está en `domain/material/materialPage.ts`.
- `createMaterial(material, { accessToken?, signal? })` envía multipart con
  `professorId` y admite DOCUMENT, PRESENTATION, EXAM, SUMMARY y LINK. El navegador
  establece el Content-Type y su boundary. Si se proporciona un token, se envía
  como Bearer; el cliente no obtiene credenciales de almacenamiento global.
- La vista `/materials/upload` envía los metadatos y el archivo con el mismo
  contrato multipart. Puede recibir un `accessToken` opcional; el flujo de login
  actual no lo persiste ni lo conecta automáticamente.
- `useCreateMaterialMutation(accessToken?)` invalida las consultas de materiales
  al completar la creación. La integración real con Auth sigue pendiente en
  backend; el token simulado de login no habilita la creación.
- `fetchMaterial` consulta el detalle real de `GET /materials/:id`. La ruta
  `/material/:materialId` presenta metadatos e historial de versiones; requiere
  un material publicado.
- `downloadMaterial` consulta `GET /materials/:id/download`. En la vista de
  detalle, el botón descarga el archivo como `Blob`; el servicio responde con
  el stream y las cabeceras de descarga. Solo hay archivo descargable si el
  material publicado tiene una versión disponible; los enlaces no tienen
  archivo.
- `fetchSearch` consulta `GET /search`; la vista `/search` ofrece búsqueda,
  orden y paginación a través del API Gateway.

La regresión manual de los siete flujos (incluidos requisitos de MinIO, datos
publicados y contexto local) está documentada en
[`docs/testing/regresion-stack-real.md`](../docs/testing/regresion-stack-real.md).

El contrato de creación corresponde a los DTO Swagger de Material Service.
Los campos marcados opcionales en Swagger permanecen opcionales en TypeScript,
aunque la implementación actual los incluya con valores null.
