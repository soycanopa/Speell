# UI — Speell

Estado: spec visual del MVP. Fecha: 2026-10-05.
Comportamiento en `UX.md`. Esto es la cara: densidad, componentes, estados. Nativo y calmo. No es un dashboard web ni un IDE.

## Tono

App de macOS, no un sitio. Fondo de sidebar ligeramente distinto al de la surface, como Finder o Terminal con sidebar. La surface es la protagonista: ocupa el ancho y el alto que queden. Chrome mínimo, tipo de sistema, iconos SF Symbols. Sin ilustraciones, sin gradientes de producto, sin tarjeta de "bienvenida".

Carlos diseña. Esta spec no sustituye un archivo de diseño: fija lo que no se improvisa en código.

## Ventana

- Título: nombre del proyecto activo. Si no hay proyecto, "Speell". Vive en `window.title` para accesibilidad, pero **no se dibuja**: la barra de título está oculta.
- **Sin barra de título.** La ventana usa `titlebarAppearsTransparent`, `titleVisibility = .hidden` y `fullSizeContentView`, que va en el `styleMask` de creación: insertado después no recalcula el layout.
- macOS sigue reservando la franja de la barra de título aunque el content view la ocupe, y el `NSSplitViewController` maqueta sus columnas contra el área reservada. Por eso la franja la ocupa **Speell**, no el sistema: un `AppBarView` de ancho completo apilado encima del contenido, dentro de un contenedor.
- **Una sola superficie de fondo para toda la ventana: `#181818`.** App bar, margen exterior y separación entre la sidebar y la terminal son el mismo color. Antes era el gris del sistema, y los huecos de 8 px se leían como un canal claro en medio de dos superficies oscuras. Vive en `SpeellPalette.windowBackground` como `NSColor`, porque lo pinta la ventana.
- **App bar: 28 pt de alto, de ancho completo.** A la izquierda, el hueco que ocupa la sidebar más el divider, para que los tabs arranquen exactamente en el borde de la terminal. Los botones de ventana, que macOS sigue dibujando sobre la sidebar, caen dentro de ese hueco: no se les reserva ancho aparte. Luego los tabs. Luego, a la derecha, la zona reservada y **vacía a propósito** para los iconos del panel que se va a desarrollar; no se inventan iconos ahí.
- El hueco del app bar lo publica el composition root como `WorkspaceModel.contentLeadingOffset`, que es el borde derecho de la sidebar —su `frame.maxX`, ya con el divider— y no su ancho. Leer el ancho y además sumar el ancho de los botones de ventana empujaba los tabs 77 px hacia dentro de la terminal.
- La sidebar se identifica **por referencia** (`WorkspaceSplitViewController.sidebarItem`), nunca por índice: `splitView.subviews.first` devuelve la terminal, no la sidebar, y esa confusion ponía los tabs 831 px a la derecha.
- El item del split es **plano** (`NSSplitViewItem(viewController:)`), no `sidebarWithViewController`: el behavior de sidebar instala detrás de toda la columna el material vibrante de macOS, que pintaba los 8 pt de separación con un tono distinto al de la ventana y tapaba las esquinas redondeadas del clip. Speell pinta sus propias superficies; detrás de la sidebar no tiene que haber nada del sistema. La sidebar fija su ancho al redimensionar (`holdingPriority` 260, lo que hacía el behavior de sidebar) y la terminal cede.
- Los tabs y el app bar **no llevan línea debajo**: la terminal llega hasta arriba.
- El alto inicial se compensa con los 38 del app bar (`setContentSize(640 + 38)`) para no entregar menos terminal que antes.
- Colapsar la sidebar: **pendiente.** Antes se usaba el botón de toolbar de macOS y ya no hay toolbar. El arrastre del divider y el `canCollapse` del split siguen funcionando; falta el control que lo dispare.
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
- Tab activa: contraste de fondo, no un subrayado de navegador. **Solo la activa lleva las cuatro esquinas redondeadas** (mismo radio que sidebar y terminal, `SpeellPalette.corner`); las inactivas van planas y se distinguen solo por el texto. Alto de tab: app bar menos 4, para que queden 2 pt de aire arriba y abajo.
- `+` al final, no una tab falsa.

## Surface

- El `NSView` de libghostty llega a los bordes del área de contenido, sin padding interno. El redondeo de la ventana es externo: 8 pt de esquinas (`SpeellPalette.cornerRadius`, radio continuo) y 8 pt de margen alrededor de todo el contenido (`SpeellPalette.windowPadding`), más 8 pt de separación entre la sidebar y la terminal. El margen va fuera del `clipShape`, para que el hueco quede sin fondo y se vea el de la ventana.
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
