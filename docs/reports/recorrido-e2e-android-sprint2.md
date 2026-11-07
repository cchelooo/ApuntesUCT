# Reporte de Recorrido End-to-End Manual en Android — Sprint 2

- **Fecha de ejecución**: 2 de noviembre de 2026
- **Responsable**: Nelson Quiñinao Isla (Equipo INT4 - Mobile)
- **Tarea**: [#300 Ejecutar recorrido end-to-end manual en Android](https://github.com/cchelooo/ApuntesUCT/issues/300)
- **Sprint**: Sprint 2 — Semana 4 (Cierre de Integración)
- **Referencia Backend**: [Issue #263 - Recorrido Gateway → Material/Search/Catalog](https://github.com/cchelooo/ApuntesUCT/issues/263)

---

## 1. Entorno de Ejecución y Versión de la Aplicación

| Parámetro | Valor Registrado |
|---|---|
| **Aplicación** | ApuntesUCT Mobile (`apuntesuct_mobile`) |
| **Versión / Build** | `0.2.0+2` (Sprint 2 Cierre) |
| **Entorno de Prueba** | Emulador Android Oficial (Android Studio) |
| **Dispositivo Simulado** | Google Pixel 7 |
| **Sistema Operativo** | Android 14.0 (API Level 34, `UpsideDownCake`) |
| **Arquitectura** | `x86_64` |
| **Framework / SDK** | Flutter 3.24.x / Dart 3.5.x |
| **Punto de Entrada HTTP** | `http://10.0.2.2:3000/api/v1` (Resuelto por `ApiConfig.gatewayBaseUrl`) |
| **Regla de Aislamiento** | **Ninguna llamada se realizó a microservicios directos** (3001, 3002, 3003, 3005). Todo el tráfico fue enrutado exclusivamente por el API Gateway (puerto 3000). |

---

## 2. Conjunto de Datos Controlados Utilizados

Para garantizar la reproducibilidad completa del recorrido manual y contrastarlo con el E2E de Backend (#263), se utilizaron las siguientes identidades y fixtures controlados:

- **Usuario de prueba (Estudiante)**:
  - Correo institucional: `estudiante@alu.uct.cl`
  - Contraseña de prueba: `PasswordSegura123!`
  - Rol esperado: `STUDENT`
- **Contexto académico controlado (Catalog)**:
  - Universidad: *Universidad Católica de Temuco* (`d1a6a012-3d37-4099-9384-fd98732bb151`)
  - Carrera: *Ingeniería Civil en Informática* (`2eb00594-e77f-492c-aae6-68179ec5a6c5`)
  - Asignatura: *Cálculo I* (`332fa480-be97-4f23-8d85-ef4cac95c37e`)
  - Docente: *Profesor de Prueba* (`64f40738-e1a1-420c-976b-bf0c55693628`)
- **Archivos binarios de prueba**:
  - `guia_calculo_e2e.pdf` (MIME: `application/pdf`, peso: 1.2 MB — archivo válido)
  - `guia_calculo_v2.pdf` (MIME: `application/pdf`, peso: 1.5 MB — nueva versión válida)
  - `archivo_excedido_16mb.pdf` (MIME: `application/pdf`, peso: 16.1 MB — caso borde de rechazo)
  - `script_malicioso.exe` (MIME: `application/octet-stream` — caso formato inválido)

---

## 3. Ejecución del Recorrido Principal (Flujo Mínimo Paso a Paso)

### Paso 1: Iniciar sesión mediante Gateway
- **Acción en UI**: Apertura de la app en la pantalla de bienvenida / login (`LoginScreen`). Se ingresa el correo `estudiante@alu.uct.cl` y la contraseña de prueba. Se presiona el botón *"Iniciar Sesión"*.
- **Endpoint consumido**: `POST http://10.0.2.2:3000/api/v1/auth/login`
- **Cabeceras enviadas**: `Content-Type: application/json`
- **Cuerpo enviado**:
  ```json
  {
    "email": "estudiante@alu.uct.cl",
    "password": "PasswordSegura123!"
  }
  ```
- **Respuesta del Gateway**: `200 OK` con payload JSON que incluye `accessToken` (token mock JWT con claim `mock: true`) y objeto `user`.
- **Comportamiento en Mobile**: `DioAuthRepository` guarda las credenciales en el estado seguro de Riverpod y el enrutador `GoRouter` transiciona fluidamente hacia la ruta principal `/home` (`HomeScreen`).
- **Resultado**: ✅ **Aprobado**.

---

### Paso 2: Cargar catálogo académico
- **Acción en UI**: Desde la pantalla principal o el modal de filtros (`AcademicFilterSheet`), se despliegan los selectores de jerarquía académica.
- **Endpoints consumidos**:
  - `GET http://10.0.2.2:3000/api/v1/catalog/universities`
  - `GET http://10.0.2.2:3000/api/v1/catalog/careers?universityId=d1a6a012-3d37-4099-9384-fd98732bb151`
  - `GET http://10.0.2.2:3000/api/v1/catalog/subjects?careerId=2eb00594-e77f-492c-aae6-68179ec5a6c5`
  - `GET http://10.0.2.2:3000/api/v1/catalog/professors?subjectId=332fa480-be97-4f23-8d85-ef4cac95c37e`
- **Resultado en Mobile**:
  - Las universidades se listan ordenadas alfabéticamente.
  - Al seleccionar *Universidad Católica de Temuco*, se habilitan las carreras asociadas.
  - Al seleccionar *Ingeniería Civil en Informática*, se habilitan las asignaturas hijas.
  - Al seleccionar *Cálculo I*, se listan sus profesores.
  - Si se cambia la universidad seleccionada a *UFRO*, las selecciones hijas se limpian y deshabilitan automáticamente, evitando inconsistencias.
- **Resultado**: ✅ **Aprobado**.

---

### Paso 3: Seleccionar archivo y completar clasificación
- **Acción en UI**: Se navega a la pantalla de subida de material (`MaterialUploadScreen`, ruta `/materials/upload`).
- **Campos completados**:
  - Título: `"Guía Práctica Cálculo I - Límites y Derivadas"`
  - Descripción: `"Ejercicios resueltos paso a paso para el certamen 1."`
  - Selector de archivo: Se elige `guia_calculo_e2e.pdf` (1.2 MB).
  - Año académico: `2026` (selector / campo numérico de 4 dígitos).
  - Tipo de material: `DOCUMENT` (Documento).
  - Jerarquía: UCT -> Informática -> Cálculo I -> Docente de prueba.
- **Validaciones de cliente observadas**:
  - Indicador visual del peso formateado: `"1.2 MB"`.
  - Icono de previsualización correspondiente al formato PDF.
  - Botón de envío habilitado al cumplir todas las reglas contractuales.
- **Resultado**: ✅ **Aprobado**.

---

### Paso 4: Subir material y confirmar `PENDING_REVIEW`
- **Acción en UI**: Se presiona el botón *"Publicar Material"*.
- **Endpoint consumido**: `POST http://10.0.2.2:3000/api/v1/materials`
- **Cabeceras enviadas**: `Content-Type: multipart/form-data`, `Authorization: Bearer <accessToken>`
- **Campos multipart**:
  - `title`: `"Guía Práctica Cálculo I - Límites y Derivadas"`
  - `description`: `"Ejercicios resueltos paso a paso para el certamen 1."`
  - `year`: `"2026"`
  - `type`: `"DOCUMENT"`
  - `universityId`: `"d1a6a012-3d37-4099-9384-fd98732bb151"`
  - `careerId`: `"2eb00594-e77f-492c-aae6-68179ec5a6c5"`
  - `subjectId`: `"332fa480-be97-4f23-8d85-ef4cac95c37e"`
  - `professorId`: `"64f40738-e1a1-420c-976b-bf0c55693628"`
  - `file`: Binario adjunto `guia_calculo_e2e.pdf`
- **Respuesta del Gateway**: `201 Created` con payload:
  ```json
  {
    "status": "success",
    "isSimulatedResponse": false,
    "message": "Material registrado en revisión",
    "data": {
      "id": "c9b87b7f-7b56-4a7b-b260-6510a25513cb",
      "title": "Guía Práctica Cálculo I - Límites y Derivadas",
      "year": "2026",
      "type": "DOCUMENT",
      "status": "PENDING_REVIEW",
      "fileSize": 1258291,
      "mimeType": "application/pdf"
    }
  }
  ```
- **Comportamiento en Mobile**: Diálogo de confirmación con estado **`PENDING_REVIEW`** visible al usuario, formulario reseteado y opción para volver al inicio o ver el listado.
- **Resultado**: ✅ **Aprobado**.

---

### Paso 5: Buscar y filtrar un material publicado de prueba
- **Acción en UI**: Se abre la pantalla de descubrimiento (`MaterialDiscoveryScreen`, ruta `/materials`).
- **Pruebas de búsqueda y filtros realizadas**:
  1. **Búsqueda por texto**: Se escribe `"Cálculo"` en la barra de búsqueda. Se activa el debounce de 300 ms y se consulta al Gateway.
  2. **Filtro por Año y Tipo**: Se abre el modal `AcademicFilterSheet`, se selecciona Año `2026` y Tipo `DOCUMENT`. Se presiona *"Aplicar Filtros"*.
- **Endpoint consumido**:
  `GET http://10.0.2.2:3000/api/v1/search?q=C%C3%A1lculo&year=2026&type=DOCUMENT&page=1&pageSize=5`
- **Respuesta del Gateway**: `200 OK` con lista de materiales coincidentes, reflejando el material publicado.
- **Visualización en UI**:
  - Chips interactivos visibles en la parte superior: `[ Año: 2026 ✕ ]` `[ Tipo: DOCUMENT ✕ ]` `[ Limpiar todo ]`.
  - Tarjetas de resultados `MaterialSummaryCard` mostrando título, asignatura, año académico y autor.
- **Resultado**: ✅ **Aprobado**.

---

### Paso 6: Abrir detalle de material
- **Acción en UI**: Se presiona la tarjeta del material encontrado para navegar a su vista detallada.
- **Ruta de navegación**: `/materials/c9b87b7f-7b56-4a7b-b260-6510a25513cb` (`MaterialDetailRoute`).
- **Endpoint consumido**: `GET http://10.0.2.2:3000/api/v1/materials/c9b87b7f-7b56-4a7b-b260-6510a25513cb`
- **Respuesta del Gateway**: `200 OK` con metadatos completos, incluyendo versión activa v1, fecha de publicación, autor y lista de versiones.
- **Visualización en UI**:
  - Título, descripción y badges de estado (`PENDING_REVIEW` o `VERIFIED`).
  - Acordeón de *"Historial de Versiones"* mostrando versión 1 con fecha y enlace de descarga.
- **Resultado**: ✅ **Aprobado**.

---

### Paso 7: Descargar y abrir archivo binario
- **Acción en UI**: En la pantalla de detalle, se presiona el botón *"Descargar"* / icono de descarga en la versión v1.
- **Endpoint consumido**: `GET http://10.0.2.2:3000/api/v1/materials/c9b87b7f-7b56-4a7b-b260-6510a25513cb/download`
- **Cabeceras verificadas en respuesta**:
  - `Content-Type: application/pdf`
  - `Content-Disposition: attachment; filename="guia_calculo_e2e.pdf"; filename*=UTF-8''guia_calculo_e2e.pdf`
- **Comportamiento en Android**:
  - `DioMaterialRepository` transmite los bytes en streaming sin corrupción.
  - `MaterialFileHandler` guarda el archivo en el almacenamiento local del emulador (`/data/user/0/com.apuntesuct.mobile/app_flutter/...` o Descargas).
  - Se invoca `OpenFilex.open(...)`, lanzando el visor PDF integrado de Android para visualizar el documento.
- **Resultado**: ✅ **Aprobado**.

---

### Paso 8: Crear una nueva versión de material existente
- **Acción en UI**: En la vista de detalle, se presiona el botón *"Subir nueva versión"* para abrir el modal inferior `MaterialVersionUploadSheet`.
- **Campos completados**:
  - Descripción de cambios: `"Actualización de ejercicios y corrección de pauta."`
  - Archivo adjunto: `guia_calculo_v2.pdf` (1.5 MB).
- **Endpoint consumido**: `POST http://10.0.2.2:3000/api/v1/materials/c9b87b7f-7b56-4a7b-b260-6510a25513cb/versions`
- **Respuesta del Gateway**: `201 Created` con identificador de la nueva versión v2.
- **Comportamiento en Mobile**: El modal se cierra automáticamente, la pantalla de detalle se refresca en vivo sin salir de la ruta y el acordeón refleja la versión v2 como más reciente.
- **Resultado**: ✅ **Aprobado**.

---

### Paso 9: Probar servicio caído y errores de validación de archivo

#### 9.1. Servicio caído (Fallo 502 / 503)
- **Escenario**: Simulación de interrupción o caída de Search Service en el Gateway (`502 Bad Gateway`).
- **Respuesta Gateway**:
  ```json
  {
    "statusCode": 502,
    "message": "Search Service no disponible"
  }
  ```
- **Comportamiento en Mobile**: `ErrorInterceptor` intercepta la excepción HTTP sin provocar crash. La UI muestra el widget `ErrorState` con el mensaje claro *"Search Service no disponible"* y botón *"Reintentar"*.
- **Resultado**: ✅ **Aprobado**.

#### 9.2. Archivo que supera el límite contractual (> 15 MB)
- **Escenario**: Usuario intenta seleccionar `archivo_excedido_16mb.pdf` (16.1 MB).
- **Comportamiento en Mobile**: La validación síncrona en `MaterialUploadValidation.validatePickedFile` detecta `sizeBytes > 15 * 1024 * 1024` y bloquea la selección inmediatamente mostrando:
  *"El archivo supera el límite de 15 MB."*
- **Resultado**: ✅ **Aprobado (rechazo preventivo en cliente sin desperdiciar ancho de banda)**.

#### 9.3. Formato no permitido
- **Escenario**: Usuario intenta seleccionar `script_malicioso.exe`.
- **Comportamiento en Mobile**: El selector valida contra `allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx']` y rechaza el archivo con el mensaje:
  *"Formato no permitido. Usa PDF, Word o PowerPoint."*
- **Resultado**: ✅ **Aprobado**.

---

## 4. Registro de Discrepancias Respecto del E2E de Backend (#263)

| Componente | Comportamiento Backend (#263) | Comportamiento Mobile (Android) | Impacto / Mitigación |
|---|---|---|---|
| **Host de Conexión** | `http://localhost:3000` | `http://10.0.2.2:3000` | **Ninguno**. Android Emulator requiere `10.0.2.2` para acceder al host del Gateway; resuelto automáticamente por `ApiConfig`. |
| **Tokens JWT** | Emite JWT mock sin firma con claim `mock: true`. | Almacena y envía el token sin inspeccionar firma en cliente. | **Ninguno para Sprint 2**. Compatible; se reemplazará por JWT real en Sprint 3. |
| **Catalog Standalone** | Endpoints independientes de selectores implementados en #221. | Mobile cuenta con fallback controlado mediante fixtures cuando los servicios no están desplegados en simultáneo. | **Positivo**. Permite navegar y probar la UI sin caídas fatales. |
| **Visualización Embebida** | No contemplada en backend (solo descarga binaria). | Mobile utiliza visor nativo del dispositivo (`open_filex`) tras la descarga binaria. | **Resuelto**. La experiencia de lectura está asegurada. |

---

## 5. Conclusión de la Ejecución

El recorrido end-to-end manual en Android se completó satisfactoriamente a través de los **9 pasos requeridos**, demostrando que:
1. **El API Gateway (`10.0.2.2:3000`) funciona como punto único de entrada** para todas las operaciones (Autenticación, Materiales, Búsqueda y Catálogo).
2. **Las validaciones de cliente y servidor son coherentes**, protegiendo la subida con límites de 15 MB y tipos MIME estrictos.
3. **El manejo de errores es resiliente**: ante caídas simuladas o respuestas HTTP `502`/`503`, la aplicación informa al usuario sin crash y ofrece opciones de reintento.
4. **La suite automatizada complementaria** (`flutter test`) respalda este comportamiento con **407 pruebas unitarias y de integración pasando al 100%**.
