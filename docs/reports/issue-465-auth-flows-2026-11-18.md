# Informe de pruebas de autenticación Web — Issue #465

**Fecha:** 2026-11-18  
**Rama:** `feature/pruebas-flujos-auth-465`  
**Resultado:** cobertura automatizada parcial; los criterios de registro,
sesión y autorización por rol no se pueden certificar con la implementación
Web presente en esta rama.

## Ejecución

- Suite Web: `npm run test:run` — 32 archivos y 238 pruebas aprobadas.
- Build y type-check: `npm run build` — aprobados.
- ESLint: `npm run lint` — aprobado.
- Pruebas dirigidas de autenticación y permisos: 3 archivos, 31 pruebas
  aprobadas.
- Prettier: los archivos modificados pasan la comprobación dirigida. La
  verificación global informa 123 archivos preexistentes con formato distinto.
- Los escenarios nuevos usan respuestas controladas para `fetch` o adaptadores
  de subida. No se contactaron Auth Service ni API Gateway reales; por tanto,
  estos resultados no son evidencia de integración de extremo a extremo.

## Cobertura ejecutada

| Flujo                                                          | Evidencia                                                                                                                                                                                                         | Resultado                                   |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| Login: credenciales rechazadas (400) y errores de servicio/red | [LoginPage.test.tsx](../../web/src/presentation/pages/LoginPage.test.tsx)                                                                                                                                         | Aprobado                                    |
| Login: respuestas 401 y 403 del Gateway                        | [LoginPage.test.tsx](../../web/src/presentation/pages/LoginPage.test.tsx)                                                                                                                                         | Aprobado; mensaje genérico, sin éxito falso |
| Login: respuesta 200 con forma de Auth Service                 | [LoginPage.test.tsx](../../web/src/presentation/pages/LoginPage.test.tsx)                                                                                                                                         | Muestra confirmación de login               |
| Subida: error 401 y rechazo 403                                | [MaterialUploadButton.test.tsx](../../web/src/presentation/components/material/MaterialUploadButton.test.tsx), [materialErrorHandler.test.ts](../../web/src/infrastructure/material/materialErrorHandler.test.ts) | Aprobado con adaptador controlado           |
| Token autenticado en una subida                                | [MaterialUploadPage.test.tsx](../../web/src/presentation/pages/MaterialUploadPage.test.tsx)                                                                                                                       | Aprobado; comprueba el header Bearer        |

El mensaje 403 de operaciones generales ahora informa falta de permisos; se
conserva el mensaje específico de autoría para cargas de versiones.

## Hallazgos y criterios pendientes

1. **Registro institucional no implementado en Web.** [RegisterPage.tsx](../../web/src/presentation/pages/RegisterPage.tsx) renderiza campos, pero el formulario solo cancela el submit. No hay validación de dominio ni llamada al Gateway; no es posible probar aceptación/rechazo de dominios sin agregar funcionalidad, fuera del alcance de esta tarea.
2. **El login no establece una sesión Web.** [LoginPage.tsx](../../web/src/presentation/pages/LoginPage.tsx) ignora el cuerpo de respuesta tras recibir 2xx y muestra éxito; no conserva el `accessToken` ni la identidad/rol. La prueba ahora simula la forma real de respuesta de Auth Service, pero no hay consumo ni persistencia del token en la aplicación.
3. **No hay ciclo de sesión o logout.** No se encontró proveedor/contexto de autenticación ni acción de cierre de sesión en `web/src`.
4. **Rutas sin protección.** [router.tsx](../../web/src/app/router.tsx) monta Perfil, Biblioteca y Subida bajo el layout principal sin un guard de autenticación; [MainLayout.tsx](../../web/src/presentation/layouts/MainLayout.tsx) tampoco verifica sesión.
5. **Permisos por rol no implementados en Web.** No se encontró un modelo/guard que aplique `STUDENT`, `MODERATOR` o `ADMIN`; las respuestas 403 solo prueban el manejo visual del error, no la autorización del rol.
6. **Token inválido/vencido.** La UI de subida maneja una respuesta 401, pero al no existir persistencia de sesión ni logout automático, no se puede validar la invalidación de una sesión activa.
7. **Integración real pendiente.** Los mocks evitan tocar servicios locales, tal como se solicitó, pero no satisfacen la nota de la Issue #465 que exige endpoints reales. Se requiere una ejecución aislada con Auth Service y Gateway para certificarla.

## Conclusión

La suite automatizada existente y los escenarios nuevos pasan, y se mejoró el
mensaje para HTTP 403. No se marca la Issue #465 como completada: registro,
sesión, protección de rutas y autorización Web por rol faltan en la aplicación
actual, y este trabajo de pruebas no implementa esas funcionalidades.
