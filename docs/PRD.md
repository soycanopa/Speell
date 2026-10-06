# PRD — Speell

Estado: decisión de producto para el MVP. Fecha: 2026-10-05.
Speell es una terminal de macOS con la surface de libghostty y un workspace de agentes encima. No es otra terminal genérica ni un chat con un panel de shell.

## Problema

La terminal de macOS no recuerda el trabajo con un agente. El hilo vive en el CLI, la ventana no sabe a qué proyecto pertenece, y si el agente termina o pide permiso mientras estás en otra app, no hay un lugar que te devuelva a esa tab.

El usuario ya no quiere parsear scrollback ni copiar el transcript a otro lado. Grok, OpenCode 2 y Agy ya persisten su propia sesión. Lo que falta es una app que agrupe esas sesiones por proyecto, las reabra con el comando de resume del agente y avise cuando hace falta una persona.

## Usuario

Primero Carlos, en macOS, aburrido de Terminal.app, con varios proyectos locales y agentes de terminal en paralelo. Después, quien trabaje igual: un repo por carpeta, un agente por tab, y la necesidad de volver al mismo hilo al día siguiente.

No es un IDE. No es un cliente de chat. No es un reemplazo de Ghostty para quien solo quiere un shell.

## Principios

- La terminal es de verdad. Cada tab es una surface de libghostty, no un emulador propio ni un webview.
- El agente es el dueño de su hilo. Speell guarda el puntero (agente, id, cwd), no una copia del transcript.
- Un proyecto es una carpeta. Las tabs de esa carpeta viven juntas.
- Avisar y llevar. Una notificación que no enfoca la tab no cuenta.
- Explícito sobre mágico. El resume es el flag del CLI, no una reconstrucción de contexto.
- Calma. Sidebar, tabs y badges. Sin dashboard.

## Qué es un superpoder

- Panel izquierdo de proyectos (carpetas de trabajo).
- Varias tabs o terminales por proyecto.
- Notificación cuando un agente terminó o pide permiso, y foco en esa tab.
- Recuperar el hilo del agente al reabrir la app, usando la sesión que el agente ya guarda.

## Agentes del MVP

Solo estos tres. Otro agente es backlog.

| Agente | Binario | Seguir el último | Hilo concreto | Store conocido |
|---|---|---|---|---|
| Grok | `grok` | `grok -c` / `grok --resume` | `grok --resume <id>` | `~/.grok/sessions/`, por cwd |
| OpenCode 2 | `opencode2` | `opencode2 -c` | `opencode2 --session <id>` | `~/.local/share/opencode2` |
| Agy (Antigravity CLI) | `agy` | `agy -c` | `agy --conversation <id>` | caché por workspace; `/resume` dentro del TUI |

El contrato de listar y de notificar se verifica contra el CLI real antes de codificar el adaptador. Si el flag no está en la documentación o en `--help` del binario pinneado, no existe.

## Goals del MVP

1. Abrir Speell, ver los proyectos, entrar a uno y tener una o más terminals libghostty en esa carpeta.
2. Lanzar Grok, OpenCode 2 o Agy en una tab, capturar el id de sesión cuando el agente lo expone, y persistir agente + id + cwd.
3. Cerrar la app y volver: la tab relanza el comando de resume en el mismo cwd. El TUI del agente pinta su propio historial.
4. Un evento de "terminó" o "pide permiso" marca la tab y, si Speell no está al frente, manda una notificación nativa que la enfoca.
5. Shell normal sigue siendo posible en una tab sin agente.

## Non-goals del MVP

- Windows, Linux, iOS.
- Tauri, GPUI, Electron, xterm.js.
- Reimplementar el emulador, el renderer o el parser VT.
- Copiar el transcript del agente a un `agent.jsonl` paralelo.
- Splits, temas, ligaduras custom, sync entre máquinas, sesión compartida.
- Más agentes (Claude Code, Codex, Cursor). Se anotan, no se construyen.
- Un protocolo neutro de chat propio. El TUI del agente es la UI del hilo.
- Telemetría.

## Historias

1. Como usuario, fijo una carpeta como proyecto y la veo en la sidebar al reabrir.
2. Como usuario, abro varias tabs en ese proyecto, cada una con su cwd y su proceso.
3. Como usuario, elijo Grok, OpenCode 2 o Agy y la tab arranca ese CLI en la carpeta del proyecto.
4. Como usuario, cierro Speell a mitad de un hilo y al volver la misma tab ejecuta el resume de ese agente.
5. Como usuario, si no hay id todavía, la tab ofrece "continuar el último de esta carpeta" (`-c`) y lo dice, no lo disfraza de resume exacto.
6. Como usuario, cuando el agente pide permiso o termina, la tab se marca y una notificación me lleva ahí.
7. Como usuario, puedo tener una tab de shell al lado de una tab de agente sin que Speell intente interpretar el shell como chat.

## Éxito

Cualitativo, en uso diario de Carlos:

- Reabrir un proyecto y continuar el hilo de ayer sin buscar el id a mano.
- Enterarse de un permiso pendiente sin mirar el scrollback.
- La surface se siente como Ghostty, no como un terminal embebido a medias.

No hay métrica de retención ni de nube. Si el resume falla, el MVP no está hecho.

## Roadmap posterior

- Adaptadores extra, uno por uno, cuando los tres primeros se usen de verdad.
- Hook más rico por agente, si el CLI lo publica, sin parsear la pantalla.
- Splits dentro del proyecto.
- Restaurar el proceso vivo (no solo el hilo) si el agente y el SO lo permiten. No es requisito del MVP: el proceso puede morir; el hilo no.

## Naming

Speell. Terminal con workspace de agentes, solo macOS, surface de libghostty. No se posiciona como IDE ni como cliente de modelo.
