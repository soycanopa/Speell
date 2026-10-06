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
- **Una sola superficie de fondo para toda la ventana: `#282828`.** App bar, sidebar, margen exterior y separación entre la sidebar y la terminal son el mismo color. Antes era `#181818` y la sidebar pintaba aparte `underPageBackgroundColor` más una capa negra, más oscura y despegada del chrome; ahora todo es un tono, el de `underPageBackgroundColor` en oscuro, con el que macOS enmarca contenido `#1E1E1E`. Vive en `SpeellPalette.windowBackground` como `NSColor`, porque lo pinta la ventana.
- **App bar: 30 pt de alto, de ancho completo.** El tope de la franja queda a 6 pt del borde de la ventana (`windowTopPadding`), más cerca del tope que el margen de los demás lados. A la izquierda, el hueco que ocupa la sidebar más el divider, para que los tabs arranquen exactamente en el borde de la terminal. Los botones de ventana, que macOS sigue dibujando sobre la sidebar, caen dentro de ese hueco: no se les reserva ancho aparte. Luego los tabs. Luego, a la derecha, la zona reservada y **vacía a propósito** para los iconos del panel que se va a desarrollar; no se inventan iconos ahí.
- El hueco del app bar lo publica el composition root como `WorkspaceModel.contentLeadingOffset`, que es el borde derecho de la sidebar —su `frame.maxX`, ya con el divider— y no su ancho. Leer el ancho y además sumar el ancho de los botones de ventana empujaba los tabs 77 px hacia dentro de la terminal.
- El app bar ignora el safe area en su raíz (`ignoresSafeArea()` en `AppBarView`). El título de 28 pt que macOS sigue reservando entra al hosting como inset: con la franja en [6, 36], 22 pt caían en la zona del sistema y SwiftUI los respetaba, empujando los tabs contra el fondo de la franja y por debajo, sobre la terminal.
- Los botones de ventana son los del sistema; en macOS 26 son puntos de vidrio monocromos —el color aparece al hover—. El sistema recorta el glifo en una línea fija a ~27,5 pt del tope sin importar dónde esté el frame (medido moviendo el frame en vivo); el círculo completo mide ~11 pt. Con `+6` sobre el centro del app bar quedan en [14,5, 25,5]: enteros y lo más bajo que la banda permite. Centrarlos en la franja (centro 26) los corta: no cabe. Se re-aplica en cada resize y en cada activación.
- La app se activa al abrir (`NSApp.activate(ignoringOtherApps:)` en el siguiente ciclo del runloop, como Ghostty): lanzada fuera de Launch Services arranca inactiva y la ventana no toma el foco.

- La sidebar se identifica **por referencia** (`WorkspaceSplitViewController.sidebarItem`), nunca por índice: `splitView.subviews.first` devuelve la terminal, no la sidebar, y esa confusion ponía los tabs 831 px a la derecha.
- El item del split es **plano** (`NSSplitViewItem(viewController:)`), no `sidebarWithViewController`: el behavior de sidebar instala detrás de toda la columna el material vibrante de macOS, que pintaba los 8 pt de separación con un tono distinto al de la ventana y tapaba las esquinas redondeadas del clip. Speell pinta sus propias superficies; detrás de la sidebar no tiene que haber nada del sistema. La sidebar fija su ancho al redimensionar (`holdingPriority` 260, lo que hacía el behavior de sidebar) y la terminal cede.
- El split view es propio (`WorkspaceSplitView`) y no pinta la línea del divisor (`dividerColor` en claro): esa línea se leía como un borde pegado al costado derecho de la sidebar. El rect del divisor sigue existiendo, así que el arrastre para redimensionar se conserva.
- Los tabs y el app bar **no llevan línea debajo**: la terminal llega hasta arriba.
- El alto inicial se compensa con el alto del app bar (`setContentSize(640 + 30)`) para no entregar menos terminal que antes.
- Colapsar la sidebar: **pendiente.** Antes se usaba el botón de toolbar de macOS y ya no hay toolbar. El arrastre del divider y el `canCollapse` del split siguen funcionando; falta el control que lo dispare.
- Tamaño mínimo pensado para una surface de 80×24 más una sidebar de 220 pt. No se bloquea por debajo si el sistema lo permite; la sidebar colapsa primero.

## Sidebar

- Ancho inicial 240 pt. Redimensionable, mínimo 180, máximo 320.
- Fondo: el mismo `#282828` de la ventana (`SpeellPalette.windowBackgroundColor`), con las esquinas de `SpeellPalette.corner`. Como el tono es idéntico, la esquina solo se lee donde el contenido la alcanza (una fila seleccionada); si algún día se quiere el borde visible, se le da un tinte propio y las esquinas ya están.
- Blur de la sidebar: **pendiente, fuera de v1.** Con la ventana opaca un material no tiene nada que difuminar, así que no se aplica. Si vuelve, necesita que la ventana deje ver el escritorio, y entonces el resto del chrome tiene que pintar su propio fondo.
- Fila de proyecto: nombre (el folder name, no el path completo), path en secundario truncado al medio, badge si alguna tab pide permiso o terminó.
- Fila activa: realce propio —rectángulo redondeado (radio 6), plano, blanco al 8%—. La selección de sistema (`NSVisualEffectView`) es un material vibrante pensado para compositar sobre la vibrancia de una sidebar de macOS; sobre el chrome plano y opaco de Speell se renderizaba como un bloque degradado ancho. Por eso la lista es propia (`ScrollView` + filas `Button`), no `List`.
- Insets naturales: contenido a 10 pt del borde del pane, realce a 4. Los insets del estilo sidebar dejan de aplicar porque ya no hay `List`: fuera compensaciones negativas.
- Sección única, "Proyectos". Sin favoritos ni grupos en v1.
- Encabezado "Proyectos" con el botón `+` a la derecha del título —como el de Finder—: añadir proyecto es una acción de la sección. El título lleva aire propio contra la primera fila (~6 pt de padding inferior) y usa 11 pt semibold secundario.
- Inset de contenido: 8 pt. El estilo sidebar mete las filas ~16 pt —demasiado holgado para un sidebar enmarcado en su propia superficie— y `listRowInsets` no lo mueve, así que se compensa con padding horizontal negativo en el contenido de la fila. La selección sigue siendo la del sistema, a lo ancho de la fila.

## Tabs

- Barra sobre la surface: es el app bar entero (30 pt), no una barra aparte.
- Tab: punto de estado, título, botón cerrar al hover o si está activa.
- Punto de estado:
  - idle: ninguno
  - trabajando: pulso breve, color secundario
  - pide permiso: ámbar
  - terminó: verde
  - falló: rojo
  - sin hook: ninguno, y el menú de la tab lo dice
- Tab activa: contraste de fondo, no un subrayado de navegador. El fondo es el tono de la terminal (`SpeellPalette.surfaceBackground`, que lee `TerminalPalette.backgroundHex`), y **la tab nace pegada a la terminal**: esquinas redondeadas solo arriba, borde inferior recto en el borde mismo del app bar —donde empieza la terminal— y sin aire entre ambas, así leen como una superficie continua. Antes flotaba con 2 pt de aire y doble redondeo (tab abajo, terminal arriba), y se veía despegada. Las inactivas van planas —solo texto— y se distinguen por eso. La tab activa cubre la franja entera —de 6 pt del tope de la ventana hasta el borde donde empieza la terminal—; su contenido (título) lleva 2 pt de aire arriba y abajo.
- `+` al final, no una tab falsa.

## Surface

- El `NSView` de libghostty llega a los bordes del área de contenido, sin padding interno. El redondeo del pane es externo: abajo en ambas esquinas y arriba en la derecha (`SpeellPalette.pane`, radio de 8). Solo arriba a la izquierda va recto: ahí nace la tab activa, y una esquina redondeada abriría una cuña de chrome justo en el empalme. La sidebar redondea solo su lado izquierdo (`SpeellPalette.sidebarPane`), el que da contra el margen de la ventana: dos esquinas redondeadas enfrentadas a través del canal se leían como un círculo entre las dos superficies. Alrededor de todo el contenido hay 8 pt de margen (`SpeellPalette.windowPadding`) y el canal sidebar–terminal también mide 8: el divisor del split ocupa 9 pt invisibles (macOS 26 no deja cambiar ni su grosor ni su estilo) que se descuentan del padding interno de la sidebar (`splitDividerAllowance`), y una tapa del color del fondo —que no intercepta el mouse— cubre el punto agarradero que el sistema dibuja en el centro del divisor. Sobre esa franja, solo al hacer hover aparece un handle en forma de pill vertical (5×16, blanco al 35%, a 4 pt del borde derecho de la franja, fundido de 0,15 s) que viaja con el divisor al arrastrarlo. El margen va fuera del `clipShape`, para que el hueco quede sin fondo y se vea el de la ventana.
- El fondo de la terminal es `#161616`. El resto del tema sigue siendo el de libghostty y el de la config del usuario; Speell solo impone ese fondo. Se aplica con un override propio (`ghostty.conf` en Application Support) que se carga **después** de la config del usuario y antes de `ghostty_config_finalize`, porque la C API del pin no expone ningún setter de color.
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
