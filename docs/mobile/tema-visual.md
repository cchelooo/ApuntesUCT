# Tema visual de Mobile

La identidad de ApuntesUCT toma como referencia la marca de la Universidad
Católica de Temuco, sin copiar la composición de sus sitios. El sistema usa los
colores institucionales para reconocer la marca y superficies propias para que
la aplicación siga siendo legible en ambos modos.

Referencias visuales:

- [UCT Virtual](https://www.uctvirtual.cl/)
- [Recursos gráficos UCT](https://recursos.uct.cl/)

## Dirección visual

- **Modo claro — Celeste claro:** fondo blanco, aire amplio, formas suaves y
  azul como acción principal. El amarillo queda como acento porque no tiene
  contraste suficiente para texto sobre blanco.
- **Modo oscuro — Carbón UCT:** fondo casi negro y capas en grafito. El celeste
  identifica foco y enlaces; el amarillo destaca la acción principal. El navy
  se conserva como color de marca, pero deja de teñir todas las superficies.

## Paleta semántica

| Uso | Claro | Oscuro |
| --- | --- | --- |
| Fondo | `#FFFFFF` | `#0E1114` |
| Superficie contenida | `#F3F7FA` | `#15191D` |
| Superficie elevada / campos | `#F3F7FA` | `#1D2329` |
| Borde | `#DCE7F0` | `#343B43` |
| Acción principal | `#0078BC` | `#FEC601` |
| Foco y enlaces | `#0078BC` | `#3DA5D9` |
| Acento | `#FEC601` | `#FEC601` |
| Texto principal | `#0F1D34` | `#F4F7FA` |
| Texto secundario | `#5B7089` | `#B4BEC8` |
| Error | `#C62828` | `#FF9A9A` |

Los nombres en código viven en `UctPalette`. Las pantallas deben consumir
`Theme.of(context).colorScheme` y no repetir valores hexadecimales.

## Tipografía

Se usa la tipografía del sistema operativo: San Francisco en iOS y Roboto en
Android. Esto evita descargar una fuente, respeta las convenciones de cada
plataforma y mantiene buena legibilidad.

La escala base es:

| Estilo | Tamaño | Peso | Uso |
| --- | ---: | ---: | --- |
| `displaySmall` | 36 | 700 | Cifras o mensajes protagonistas |
| `headlineMedium` | 32 | 700 | Título principal de pantalla |
| `headlineSmall` | 24 | 700 | Título de sección |
| `titleLarge` | 22 | 700 | Encabezado de tarjeta o vista |
| `titleMedium` | 16 | 700 | Subtítulo y controles destacados |
| `bodyLarge` | 16 | 400 | Lectura principal |
| `bodyMedium` | 14 | 400 | Texto habitual |
| `bodySmall` | 12 | 400 | Ayuda y metadatos |
| `labelLarge` | 14 | 700 | Botones |
| `labelMedium` | 12 | 600 | Etiquetas |

No se deben fijar colores dentro de `TextStyle`; el color lo entrega el tema.

## Componentes base

- Los controles táctiles principales tienen al menos 48–54 px de alto.
- Botones, campos, tipografía y espacios conservan la misma geometría al cambiar
  de tema. Sólo el acento decorativo se desplaza por la curva, transformando el
  sol amarillo de la izquierda en una luna blanca a la derecha.
- Los botones principales usan un rectángulo redondeado de 12 px en ambos modos.
- Los campos usan relleno y borde visible; el foco es azul en claro y celeste en
  oscuro.
- Las tarjetas tienen 16 px de radio, borde sutil y no dependen de sombras.
- Los botones principales son azules en claro y amarillos en oscuro.
- Los enlaces son azules en claro y celestes en oscuro.
- Barras de navegación, tarjetas y mensajes flotantes toman sus superficies del
  `ColorScheme`; así las nuevas pantallas heredan el tema automáticamente.

## Accesibilidad

El texto principal del modo oscuro supera contraste AAA sobre el fondo y el
texto secundario, los enlaces celestes y los controles superan AA. El amarillo
no se usa como texto sobre blanco. El color nunca debe ser la única señal de un
estado: debe acompañarse con texto o iconografía.
