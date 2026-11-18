# Publicación y verificación de materiales

Tarjeta y detalle usan el mismo componente de estado y muestran `verified`
como dato separado. `verified: true` no publica un material pendiente,
rechazado o retirado. Ausencia del booleano significa sin verificación; un
valor incompatible se rechaza como contrato inválido.

El contrato Material de main usa `PENDING_REVIEW`, `PUBLISHED`, `REJECTED` y
`WITHDRAWN`. Se reconoce `RETIRED` como retirado sin reescribir ese código al
serializar. `APPROVED` permanece únicamente como compatibilidad de datos
anteriores, identificado como legado: no habilita descarga pública. Los
estados desconocidos tampoco se presentan como publicados.

Solo `PUBLISHED` habilita descarga e historial público de archivos. LINK no
ofrece descarga binaria ni nueva versión. La subida de una versión además
requiere una identidad activa que coincida con `uploaderId`; el servidor
siempre vuelve a verificar la firma y la propiedad. Estas condiciones no
conceden permisos de moderación ni sustituyen autorización del servidor.

## Dependencia de INT2

Main todavía no entrega un objeto de capacidades por material ni publica las
transiciones definitivas de Quality S3-04. No se inventan campos `canApprove`,
`canVerify`, etc., ni endpoints. Las acciones actuales aplican conservadoramente
las reglas publicadas de lectura y autoría de Material. Cuando INT2 publique
capacidades habrá que consumirlas y confirmar esa integración; este cambio no
acredita esa parte pendiente del contrato de #399/#444.

Verificación: `flutter analyze` y `flutter test`, incluidos estados, booleano,
serialización, acciones, autor y pantallas de 320 px en ambos temas. Los casos
no publicados y de Quality son datos controlados: la API pública de main solo
lista y detalla materiales publicados. No se modifica Backend para producir
una falsa evidencia de integración.
