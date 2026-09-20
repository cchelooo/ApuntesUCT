# Diagramas del proyecto

Los diagramas se separan por equipo para distinguir su propósito y evitar
mantener copias ambiguas en distintas carpetas.

## INT2

`int2/` contiene los diagramas mantenidos por el equipo responsable de Web,
backend e infraestructura:

- arquitectura;
- componentes;
- modelo entidad-relación general;
- casos de uso de Auth, Search/Catalog y Material/Quality.

## INT4

`int4/` contiene los diagramas mantenidos por el equipo Mobile e incorporados
en el SRS ubicado en `docs/project/latex/SRS_ApuntesUCT.tex`:

- arquitectura;
- componentes;
- modelos entidad-relación separados por microservicio.

El fuente editable del diagrama de componentes es
`int4/diagrama_componentes.puml`. Al modificarlo también debe regenerarse
`int4/diagrama_componentes.png` para mantener actualizado el SRS.

La documentación de la estructura Flutter no es un diagrama y se encuentra en
`docs/mobile/estructura-proyecto-mobile.md`.
