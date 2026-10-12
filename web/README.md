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

**Revisar material** muestra un resumen local editable. Esta tarea es de
maquetación: no hace POST ni persiste los datos al salir o recargar. La
validación de tamaño, MIME, año y relaciones de dominio permanece en Material
Service; el navegador solo comprueba campos requeridos y sintaxis de URL.

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
