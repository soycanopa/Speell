# UX — Speell

Estado: comportamiento del MVP. Fecha: 2026-10-05.
La UI visual está en `UI.md`. Aquí está qué hace la app, no cómo se pinta.

## Layout mental

Una ventana. Izquierda: proyectos. Derecha: el proyecto activo, con una barra de tabs y una surface que ocupa el resto. No hay panel de chat. El hilo se lee en la terminal, porque el agente ya tiene TUI.

```text
+------------------+----------------------------------------+
| Proyectos        |  tab shell   tab grok   tab agy    +   |
|  speell          |----------------------------------------|
|  circulo         |                                        |
|  mata            |            surface libghostty          |
|                  |                                        |
+------------------+----------------------------------------+
```

El teclado, cuando la surface tiene foco, es de la surface. Speell no se come las teclas del agente.

## Objetos

- Proyecto: carpeta fijada. No es un workspace multi-root.
- Tab: shell o agente. Pertenece a un proyecto.
- Sesión de agente: puntero al hilo que el CLI ya guarda. No es un mensaje en Speell.
- Aviso: la tab necesita a la persona, o el agente terminó.

## Proyectos

- Añadir proyecto: selector de carpeta. Se guarda el path. Si el path desaparece, la fila queda en estado roto, no se borra sola.
- Menú contextual de la fila: cambiar nombre (vive solo en Speell, la carpeta queda igual), archivar y eliminar. Eliminar no borra el disco. Pide confirmación.
- Archivar saca el proyecto de la sidebar y lo deja en settings → Archivados, desde donde se recupera con sus tabs. Volver a fijar una carpeta archivada también la recupera. Archivar no pide confirmación: es reversible.
- Seleccionar un proyecto restaura sus tabs. El último proyecto activo vuelve a abrirse al lanzar Speell; los archivados no cuentan.
- Orden: última actividad arriba. Sin carpetas anidadas de proyectos en v1.

## Tabs

- `+` pregunta shell o agente. Si agente, pregunta Grok, OpenCode 2 o Agy.
- Cerrar tab mata ese proceso. Si era un agente con id, el puntero queda en "recientes" del proyecto para poder reabrir.
- Renombrar tab es local. No renombra la sesión dentro del CLI.
- No hay drag entre proyectos en v1.

## Lanzar y retomar

Al crear una tab de agente:

1. Speell lista hilos de esa carpeta, si el adaptador sabe.
2. El usuario elige uno, o "nuevo", o "último de esta carpeta".
3. La surface arranca el comando. La tab muestra la calidad: exacta, última, o nueva.
4. Si más tarde aparece un id fiable, la tab pasa a exacta sin pedir nada.

Al reabrir la app se repite el comando guardado. No se muestra un transcript propio mientras carga. Si el binario no está en `PATH`, la tab lo dice y no reintenta en bucle.

## Avisos

Estados de tab: idle, trabajando, pide permiso, terminó, falló, sin hook.

- Pide permiso y terminó son los únicos que notifican fuera de la app.
- La notificación enfoca Speell, el proyecto y la tab. Si el usuario la descarta, el badge sigue hasta que la tab toma foco.
- Trabajando no notifica.
- Sin hook no simula permiso. La tab puede mostrar un punto neutro de "este agente no avisa".

## Shell

Una tab shell es una surface en el cwd del proyecto, shell de login del usuario. No tiene resume de hilo. Al volver, cwd sí, scrollback no. Vacío es el comportamiento correcto.

## Teclado mínimo

- `Cmd+N` no crea documento. No aplica.
- `Cmd+T` nueva tab en el proyecto activo.
- `Cmd+W` cierra tab.
- `Cmd+1…9` cambia de tab.
- `Cmd+Shift+[` / `]` proyecto anterior / siguiente, si no chocan con libghostty. Si chocan, ganan las teclas de la surface y estos atajos se mueven. No se adivina: se prueba en el spike.
- Flechas, enter y atajos del agente no se interceptan con la surface enfocada.

## Vacío y error

- Sin proyectos: una acción, "Abrir carpeta". Nada de ilustración de onboarding.
- Sin tabs: "Nueva terminal" y "Nuevo agente".
- CLI ausente: nombre del binario y que no está en `PATH`. Sin instalar desde la app.
- Resume que el CLI rechaza: la tab muestra la salida del propio CLI. Speell no traduce el error a un ensayo.

## Qué no hace la UX

- No hay burbujas de chat.
- No hay diff viewer.
- No hay aprobaciones propias. El permiso se contesta en el TUI del agente. Speell solo lleva ahí.
- No hay modo foco que esconda la sidebar en v1, salvo el colapso manual de la sidebar.
