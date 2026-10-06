# TRD — Speell

Estado: decisiones técnicas del MVP. Fecha: 2026-10-05.
Este documento fija el corte. Si una tarea lo contradice, se para y se pregunta. No se "aprovecha" para cambiar de stack.

## Corte

App nativa de macOS. Swift. AppKit dueño de la ventana, los splits si algún día existen, y el ciclo de vida de la surface. SwiftUI para la sidebar, la lista de sesiones y los toasts. La terminal es libghostty completo, enlazado como xcframework, dibujando con Metal en un `NSView`.

Descartado para v1: Tauri, GPUI, Electron, xterm.js, `libghostty-vt` como renderer propio, Windows, Linux.

## Por qué este corte

El C API de libghostty que pinta es el que ya consume la app de Ghostty en macOS. Se le entrega un `NSView` y la surface renderiza. El webview de Tauri no hospeda esa surface. `gpui-libghostty` existe, pero deja fuera Windows y X11 y no es el host que Ghostty usa. Como el producto es solo macOS, el host correcto es el de la app de Ghostty: Swift + AppKit + SwiftUI.

## Qué es de libghostty

Por tab, una surface. Incluye grilla VT, scrollback en memoria, reflow, ligaduras, teclado, color, hilo de IO y dibujo Metal. Speell no parsea escapes ni arma un atlas.

Build del motor, dentro de un checkout de Ghostty pinneado:

```bash
zig build -Demit-xcframework=true -Dxcframework-target=native \
  -Demit-macos-app=false -Doptimize=ReleaseFast
```

El commit queda escrito en el repo (archivo de pin, no "latest"). La API no es estable. Actualizar el pin es un cambio explícito, con nota de qué se rompió.

Referencia de integración, no de copia: la app macOS de Ghostty (`ghostty_runtime_config_s`, platform macos con `nsview`) y el writeup de Calyx sobre embeber libghostty. Ideas sí. No se copia código de un proyecto cuya licencia no hayamos leído. Ghostty es MIT; igual no se vende su app como base. Speell enlaza la librería.

## Qué es de Speell

| Módulo | Responsabilidad | No hace |
|---|---|---|
| `App` | Composition root. Ventana, menú, restauración. | No habla con un CLI de agente. |
| `Projects` | Carpetas fijadas, orden, última actividad. | No lanza procesos. |
| `Terminal` | Una surface libghostty, PTY/cwd, foco de teclado. | No interpreta el agente. |
| `Sessions` | Puntero `{ agent, sessionId?, cwd, title, projectId }`. | No guarda transcript. |
| `Agents` | Un adaptador por CLI. Listar, lanzar, resumir. | No dibuja UI. |
| `Hooks` | Traduce un evento externo a "terminó" / "pide permiso" / "idle". | No parsea el viewport para adivinar. |
| `Notify` | Badge en tab + `UNUserNotificationCenter` que enfoca la tab. | No es un inbox. |

Dirección de dependencia, una sola vía:

`App → Projects / Notify → Sessions → Agents`
`Terminal` no importa `Agents`. `Agents` no importa SwiftUI ni AppKit. El composition root es el único que une una tab con un adaptador.

## Arquitectura modular

Clean code no es un estilo. Es la condición para poder sumar un cuarto agente o una notificación sin reescribir la ventana.

Tres capas, y no se cruzan:

- Dominio. Tipos y reglas: `Project`, `Tab`, `SessionRef`, `Command`, `HookEvent`, `resumeQuality`. Sin UIKit, sin SwiftUI, sin libghostty. Se testea sin ventana.
- Adaptadores. Un archivo por agente (`GrokAdapter`, `OpenCode2Adapter`, `AgyAdapter`) más el protocolo `AgentAdapter`. Hablan con el CLI. No saben qué vista los muestra.
- Interfaz. SwiftUI para sidebar, tabs y toasts. AppKit solo para la ventana y el `NSView` de la surface. La vista recibe estado y emite intención (`selectProject`, `resumeSession`). No arma el argv del CLI ni lee `~/.grok`.

Un archivo, una responsabilidad. Si un archivo crea la ventana, lista sesiones y formatea la notificación, se parte antes de mergear. Tope orientativo: 200 líneas. Pasarse pide partir, no un comentario de "luego".

Layout de partida:

```text
Sources/Speell
  App/            composition root, menú, ciclo de vida
  Domain/         modelos y reglas de resume
  Projects/       fijar carpeta, orden, path roto
  Sessions/       puntero y store
  Agents/         protocolo + un archivo por CLI
  Hooks/          OSC y traducción a HookEvent
  Notify/         badge y notificación, sin decidir el texto de dominio
  Terminal/       host de la surface, foco, kill del hijo
  UI/             vistas SwiftUI, una vista por archivo
```

Prohibido: `SpeellApp.swift` con la lógica dentro, un `ViewModel` de 800 líneas, un `switch agent` repartido por las vistas, copiar el mismo comando de resume en la UI y en el adaptador. El `switch` del agente vive en el composition root. La vista solo muestra el nombre.

## Modelo de sesión

Speell no duplica el hilo. El agente ya lo persiste.

```text
Project
  id, path, displayName, lastActiveAt
Tab
  id, projectId, kind: shell | agent
  cwd
  agent?: grok | opencode2 | agy
  sessionId?: string          # nil hasta que el adaptador lo confirme
  resumeQuality: exact | latestInDir | fresh
  title
  notifyState: idle | needsPermission | finished | failed
```

Persistencia local, en disco del usuario (Application Support). JSON o SQLite de una tabla: da igual en el spike; se elige en la fase 1 y no se migran los dos. No hay nube.

Al restaurar:

- `resumeQuality == exact` y hay `sessionId` → comando de resume de ese id.
- no hay id → comando `-c` de ese agente, y la UI dice "último de esta carpeta", no "esta sesión".
- `kind == shell` → shell del usuario en `cwd`. No se intenta resume.

## Adaptadores

Interfaz mínima. Nada de protocolo de chat.

```text
list(cwd) -> [SessionRef]
launch(cwd) -> Command
resume(cwd, id) -> Command
continueLatest(cwd) -> Command
observe(tab) -> AsyncStream<HookEvent>   # puede ser vacío en v1 si el CLI no publica hook
```

`Command` es binario + args + env + cwd. La tab lo ejecuta dentro de la surface.

Flags de partida, a revalidar con `--help` del binario antes de implementar:

- Grok: `grok`, `grok -c`, `grok --resume <id>`, `grok sessions list`. Store `~/.grok/sessions/`.
- OpenCode 2: `opencode2`, `opencode2 -c`, `opencode2 --session <id>`. Datos en `~/.local/share/opencode2`, no en el store de `opencode`.
- Agy: `agy`, `agy -c`, `agy --conversation <id>`.

Orden de implementación: Grok, OpenCode 2, Agy. Agy es el más opaco para listar; no se bloquea el MVP de Grok por eso.

Prohibido leer la base del agente como fuente de verdad si el CLI tiene listado JSON. Leer disco es fallback documentado, solo para Agy si `--help` no ofrece lista.

## Hooks

Separados del resume. Retomar un hilo no dice que el agente espera un permiso.

Orden de fuentes, por adaptador, de mejor a peor:

1. Hook o evento que el CLI documenta (permiso, stop, idle).
2. Secuencia de terminal ya estándar: OSC 9 y OSC 777 (`notify`).
3. No se usa el viewport como detector. Si no hay fuente 1 ni 2, la tab no finge el aviso: queda en "sin hook" y se anota.

La notificación nativa solo se dispara si Speell no está activa. Si está activa, basta el badge en la tab y un toast que enfoca.

## Terminal y proceso

Una surface por tab. Cerrar la tab mata el proceso de esa surface. Cerrar la app mata los procesos. El MVP no promete proceso vivo entre launches: promete el hilo, vía resume.

El scrollback de libghostty no se serializa en v1. Al volver, el TUI del agente rehidrata. Una tab shell vuelve vacía, en el mismo cwd. Eso se dice en la UI, no se esconde.

## Plataforma

- macOS actual que soporte el pin de Ghostty (se fija en el spike).
- Swift tools del Xcode que compile el host.
- Zig solo para producir el xcframework, no como lenguaje de la app.
- Notificaciones: autorización de UserNotifications, pedida en el primer aviso, no en el primer launch.

## Seguridad

- Sin telemetría.
- No se copian API keys de los agentes. Esos CLI ya están autenticados en la máquina.
- Un adaptador no recibe el env completo por defecto: cwd, `PATH`, y lo que el CLI documente. No se loguea el env.
- Confirmar antes de borrar un proyecto de la sidebar (no borra la carpeta del disco) y antes de descartar un puntero de sesión.

## Riesgos

- API de libghostty inestable. Mitigación: pin y un spike que solo abre un shell.
- Id de sesión no disponible al nacer el TUI. Mitigación: degradar a `-c` y marcarlo.
- Hook inexistente en algún CLI. Mitigación: el adaptador declara `hooks: none` y el producto no promete aviso para ese agente hasta que exista fuente.
- Liquid Glass / ventana no opaca contra la surface Metal. Se resuelve en el spike, no se diseña a ciegas.
