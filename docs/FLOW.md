# FLOW — Speell

Estado: flujos del MVP. Fecha: 2026-10-05.
Cada flujo tiene un resultado observable. Si el código no puede señalar en qué paso está, el flujo no está implementado.

## Estados de una tab

```text
vacía
  → lanzando
  → viva (shell | agente)
  → viva + aviso (permiso | terminó | falló)
  → cerrada (proceso muerto, puntero conservado si había id)
  → restaurando
  → viva
```

`sin hook` no es un estado de vida. Es una capacidad del adaptador. La tab puede estar viva y sin hook.

## F0 — Primer launch

1. Ventana con sidebar vacía y área vacía.
2. Una acción: abrir carpeta.
3. No se pide permiso de notificaciones todavía.
4. No se lanza ningún CLI.

Hecho: la app abre y cierra sin procesos huérfanos.

## F1 — Fijar proyecto

1. Abrir carpeta.
2. Se crea `Project` con path y nombre.
3. Se abre una tab shell en ese cwd.
4. La fila queda seleccionada.

Hecho: al relanzar, el proyecto sigue y la tab shell vuelve al mismo cwd, vacía.

## F2 — Nueva tab de agente

1. `+` → agente → Grok | OpenCode 2 | Agy.
2. Si `list(cwd)` devuelve hilos, se muestran título e id. Acciones: abrir ese, último de la carpeta, nuevo.
3. Si no hay lista, solo "nuevo" y "último de la carpeta".
4. La surface ejecuta el `Command` del adaptador.
5. Si el adaptador obtiene id, `resumeQuality` pasa a exacta.

Hecho: el proceso es hijo de esa tab. Cerrar la tab lo mata. El puntero queda.

## F3 — Restaurar

1. Launch con proyectos guardados.
2. Se abre el último proyecto y sus tabs.
3. Tab shell → shell en cwd.
4. Tab agente con id → `resume(cwd, id)`.
5. Tab agente sin id → `continueLatest(cwd)`, etiqueta visible de que es el último, no ese hilo.

Hecho: no se pinta un transcript de Speell. El TUI del agente, o el shell, es lo único en la surface.

## F4 — Aviso

1. Llega un `HookEvent` del adaptador (hook del CLI u OSC 9/777).
2. La tab cambia el punto. La sidebar marca el proyecto.
3. Si la ventana no está activa, notificación nativa. El primer aviso pide autorización; si el usuario niega, solo queda el badge.
4. Click en notificación o toast: proyecto + tab al frente, surface con foco.

Hecho: contestar el permiso ocurre dentro del TUI, no en un modal de Speell.

## F5 — Agente sin hook

1. El adaptador declara que no hay fuente.
2. La tab no muestra punto de permiso.
3. El menú de la tab dice que este agente no avisa.

Hecho: no hay heurística de scrollback.

## F6 — CLI ausente o resume rechazado

1. Binario no está en `PATH`: la tab no reintenta. Mensaje con el nombre del binario.
2. El CLI arranca y rechaza el id: se muestra su salida. Speell no borra el puntero sola. El usuario puede pasar esa tab a "último" o a "nuevo".

## F7 — Quitar proyecto

1. Confirmación: se quita de la sidebar, la carpeta queda.
2. Tabs de ese proyecto se cierran y sus procesos mueren.
3. Punteros de ese proyecto se borran de Speell. Los hilos siguen en el store del agente.

## F8 — Quit

1. Se persiste proyecto activo, tabs, punteros, cwd.
2. Se cierran surfaces y se espera a que los hijos mueran, con timeout corto.
3. No quedan `grok` / `opencode2` / `agy` lanzados por Speell.

Hecho: un segundo quit no es necesario para recoger huérfanos. Si el timeout gana, se documenta el pid y se mata.

## Fuera de estos flujos

Sync, compartir sesión, splits, drag de tabs entre proyectos, relanzar un proceso que nunca murió, aprobar un permiso desde la notificación.
