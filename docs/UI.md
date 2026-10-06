# UI — Speell

Estado: spec visual del MVP. Fecha: 2026-10-05.
Comportamiento en `UX.md`. Esto es la cara: densidad, componentes, estados. Nativo y calmo. No es un dashboard web ni un IDE.

## Tono

App de macOS, no un sitio. Fondo de sidebar ligeramente distinto al de la surface, como Finder o Terminal con sidebar. La surface es la protagonista: ocupa el ancho y el alto que queden. Chrome mínimo, tipo de sistema, iconos SF Symbols. Sin ilustraciones, sin gradientes de producto, sin tarjeta de "bienvenida".

Carlos diseña. Esta spec no sustituye un archivo de diseño: fija lo que no se improvisa en código.

## Ventana

- Título: nombre del proyecto activo. Si no hay proyecto, "Speell".
- Traffic lights estándar. Sidebar colapsable con el botón de toolbar de macOS.
- Toolbar: nombre del proyecto, botón de nueva tab, y nada más en v1. Ajustes viven en el menú de la app, no en un engranaje flotante.
- Tamaño mínimo pensado para una surface de 80×24 más una sidebar de 220 pt. No se bloquea por debajo si el sistema lo permite; la sidebar colapsa primero.

## Sidebar

- Ancho inicial 240 pt. Redimensionable, mínimo 180, máximo 320.
- Fondo: una capa negra al 8% sobre el fondo de la ventana, en `UI/SpeellPalette.swift`. Va **detrás** del contenido, no encima, para no atenuar el texto.
- Blur de la sidebar: **pendiente, fuera de v1.** Con la ventana opaca un material no tiene nada que difuminar, así que no se aplica. Si vuelve, necesita que la ventana deje ver el escritorio, y entonces el resto del chrome tiene que pintar su propio fondo.
- Fila de proyecto: nombre (el folder name, no el path completo), path en secundario truncado al medio, badge si alguna tab pide permiso o terminó.
- Fila activa: selección del sistema (`NSVisualEffect` / selección de lista), no un azul inventado.
- Sección única, "Proyectos". Sin favoritos ni grupos en v1.
- Pie: "Añadir proyecto".

## Tabs

- Barra sobre la surface, altura de control de macOS (~28 pt).
- Tab: punto de estado, título, botón cerrar al hover o si está activa.
- Punto de estado:
  - idle: ninguno
  - trabajando: pulso breve, color secundario
  - pide permiso: ámbar
  - terminó: verde
  - falló: rojo
  - sin hook: ninguno, y el menú de la tab lo dice
- Tab activa: contraste de fondo, no un subrayado de navegador.
- `+` al final, no una tab falsa.

## Surface

- El `NSView` de libghostty llega a los bordes del área de contenido. Sin padding decorativo, sin marco redondo que recorte glifos.
- El fondo de la terminal es `#1E1E1E`. El resto del tema sigue siendo el de libghostty y el de la config del usuario; Speell solo impone ese fondo. Se aplica con un override propio (`ghostty.conf` en Application Support) que se carga **después** de la config del usuario y antes de `ghostty_config_finalize`, porque la C API del pin no expone ningún setter de color.
- Cursor y selección son de libghostty.
- Cuando la tab está restaurando, un overlay de una línea: "Retomando sesión" o "Abriendo último hilo de esta carpeta". Desaparece al primer frame con contenido. No es un spinner de pantalla completa.

## Aviso

- In-app: toast arriba a la derecha del área de tabs, 4 segundos, título del agente y "pide permiso" o "terminó". Click enfoca la tab.
- Fuera de la app: notificación del sistema con el mismo texto y el nombre del proyecto. Click hace lo mismo.
- No hay centro de notificaciones dentro de Speell. El badge de la sidebar y el punto de la tab son el inbox.

## Diálogos

- Añadir proyecto: `NSOpenPanel`, solo directorios.
- Cerrar tab de agente: no confirma. El hilo sigue en el CLI.
- Quitar proyecto de la sidebar: confirma, y el texto dice que la carpeta no se borra.
- CLI no encontrado: alerta pequeña en la tab, no un modal de app.

## Tipo y color

- Texto de chrome: sistema, 13 pt regular para filas, 11 pt para path secundario.
- Color de acento: el del sistema. No hay marca de color en v1.
- Estados (ámbar, verde, rojo) solo en el punto de 8 pt y en el badge numérico de la sidebar. No se pinta la tab entera.
- Modo claro y oscuro desde el primer día, porque la surface Metal se ve mal si el chrome no sigue al sistema.

## Movimiento

Casi ninguno. Cambio de proyecto instantáneo. Toast entra y sale en la curva del sistema. Sin transiciones de "terminal que vuela".

## Accesibilidad

- Sidebar y tabs son listas y botones reales, no rectángulos con gesto.
- El punto de estado tiene label ("Pide permiso", "Terminó").
- La surface queda fuera de VoiceOver en v1, igual que una terminal nativa; no se promete lo contrario.

## Fuera de esta spec

Splits, paleta de comandos, temas, iconos por agente más allá de un glifo SF Symbol de 12 pt junto al título, ventana de settings con formulario largo.
