# Speell

Terminal de macOS con la surface de [libghostty](https://github.com/ghostty-org/ghostty) y un workspace de agentes encima. Las tabs se agrupan por proyecto, retoman el hilo del CLI del agente y avisan cuando hace falta una persona.

No es un IDE, ni un cliente de chat, ni otra terminal genérica. Cada tab es una surface real de libghostty; Speell no parsea VT ni copia el transcript.

## Estado

Pre-MVP. Solo especificación y decisiones. Aún no hay código: la primera tarea es el spike de surface (Fase 0).

## Qué hace

- Sidebar de proyectos (carpetas de trabajo), varias tabs por proyecto.
- Tabs de shell o de agente: **Grok** (`grok`), **OpenCode 2** (`opencode2`), **Agy** (`agy`).
- Al reabrir, cada tab relanza el comando de resume del agente (id exacto, o `-c` "último de esta carpeta", dicho en la UI).
- Aviso de "terminó" o "pide permiso" con badge, toast y notificación nativa que enfoca la tab.
- Speell guarda el puntero `{ agent, sessionId?, cwd, title }`. El hilo vive en el CLI.

Detalle de producto en [`docs/PRD.md`](docs/PRD.md).

## Stack

- Swift. AppKit para la ventana y el ciclo de vida de la surface; SwiftUI para chrome y sidebar.
- libghostty completo (xcframework pinneado) dibujando con Metal en un `NSView`. Zig solo para producir el xcframework.
- Solo macOS en v1. Sin Tauri, GPUI, Electron ni xterm.js.

Decisiones técnicas y cut en [`docs/TRD.md`](docs/TRD.md).

## Estructura

```text
docs/       PRD, TRD, UX, UI, FLOW, IMPLEMENTACION, decisions/
Vendor/     ghostty.pin (commit del motor) y el xcframework generado (no commiteado)
Scripts/    build-libghostty.sh
Tests/      tests de persistencia
AGENTS.md   reglas de trabajo del repo
Sources/Speell/
  App/        composition root: main, ventana, menú, controller del workspace
  Domain/     Project, Tab
  Projects/   alta, baja, orden y path roto
  Sessions/   tabs por proyecto y su store
  Terminal/   host de libghostty, pane, surface, entrada
  UI/         sidebar, barra de tabs, vacíos
  (pendiente: Agents, Hooks, Notify)
```

Del TRD, dirección de dependencia: `App → Projects / Notify → Sessions → Agents`. `Terminal` no importa `Agents`; `Agents` no importa SwiftUI ni AppKit.

## Build

Requiere Xcode, no CommandLineTools: de ahí salen `xcodebuild -create-xcframework` y los macros de SwiftUI que usa la sidebar.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer  # o: sudo xcode-select -s /Applications/Xcode.app
Scripts/build-libghostty.sh   # zig del pin si falta, clona Ghostty y genera el xcframework
swift build
swift test
swift run Speell
Scripts/build-libghostty.sh --verify   # compara el artefacto con el hash commiteado
```

El pin (commit de Ghostty + versión de zig) vive en `Vendor/ghostty.pin`; el porqué, en [`docs/decisions/0001-pin-libghostty.md`](docs/decisions/0001-pin-libghostty.md).

## Estado en disco

`~/Library/Application Support/Speell/`: `projects.json` y `tabs.json`. Ver [`docs/decisions/0002-persistencia.md`](docs/decisions/0002-persistencia.md).

## Documentos

| Doc | Contenido |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | producto, usuario, goals y non-goals del MVP |
| [`docs/TRD.md`](docs/TRD.md) | corte técnico, módulos, adaptadores, hooks, riesgos |
| [`docs/UX.md`](docs/UX.md) | comportamiento: proyectos, tabs, resume, avisos, teclado |
| [`docs/UI.md`](docs/UI.md) | spec visual: ventana, sidebar, tabs, surface, diálogos |
| [`docs/FLOW.md`](docs/FLOW.md) | flujos F0–F8 con resultado observable |
| [`docs/IMPLEMENTACION.md`](docs/IMPLEMENTACION.md) | orden de construcción por fases |

## Licencia

Source-available bajo [Functional Source License 1.1, ALv2 Future License](LICENSE) (`FSL-1.1-ALv2`).

Puedes usar, copiar, modificar y redistribuir Speell para cualquier propósito excepto **Competing Use**: ofrecerlo a otros como producto o servicio comercial que sustituya a Speell o dé la misma funcionalidad. Uso interno, educación e investigación no comercial quedan permitidos. Cada versión pasa a **Apache 2.0** a los dos años de publicarse.

No es una licencia Open Source ni OSI-approved. libghostty y demás dependencias conservan su licencia propia (Ghostty es MIT); Speell solo enlaza la librería.
