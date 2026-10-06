# 0006 — Fuentes de aviso por agente

Fecha: 2026-10-06. Estado: verificado contra las fuentes primarias de cada CLI.

Fase 4 pide, por agente y en orden: hook documentado, si no OSC 9/777, si no
`hooks: none`. Este documento fija qué canal tiene cada binario y con qué
evidencia; el protocolo `AgentAdapter` lo declara (`noticeSource`) y la
configuración lo muestra tal cual. Nada de detectar estado leyendo el
scrollback ni el viewport.

## Grok — `.osc` (OSC 9/777)

Primera pasada declaró `hooks: none` desde el `--help` de nivel superior.
**Era un error**: el manual embebido del binario (`~/.grok/docs/user-guide/`)
documenta el canal completo. La lección queda: el `--help` de nivel superior
no es la fuente primaria completa de un CLI con manual propio.

Evidencia:

- `05-configuration.md` (sección Notifications, dentro de `[ui]`): "Fire
  terminal notifications when the agent finishes a turn or needs approval.
  They use terminal-native protocols (OSC 9, OSC 99, OSC 777, or BEL)". La
  matriz de terminales del mismo archivo: **Ghostty → OSC 777, con focus
  tracking**.
- Defaults (sin escribir una línea de config): `method = "auto"`,
  `condition = "unfocused"`, `idle_threshold_secs = 3`,
  `events = ["turn_complete", "approval_required"]`. Exactamente la semántica
  de F4: terminó la vuelta o pide permiso, solo cuando no estás mirando.
  El `config.toml` real del usuario no toca la sección.
- `21-terminal-support.md`: "Grok detects these terminal emulators from
  environment variables", Ghostty en la lista.
- El pin inyecta `TERM_PROGRAM=ghostty` en los procesos hijos
  (`src/termio/Exec.zig`, en torno a la línea 750), así que grok dentro de
  una surface de Speell se detecta como Ghostty.
- El foco ya se reporta a libghostty desde `AppDelegate`
  (`host.setFocus`), que es lo que el gating `unfocused` de grok necesita.
- Cadena completa: grok emite OSC 777 → libghostty la entrega como
  `GHOSTTY_ACTION_DESKTOP_NOTIFICATION` → `GhosttyHost.handleAction` →
  `AgentNotice.agentMessage` → punto y notificación. Cero código nuevo de
  detección.

No se usan en v1 los otros dos canales de grok, ambos documentados en
`10-hooks.md`: hooks de ciclo de vida (`Notification` con matchers
`permission_prompt` / `task_complete` / `idle_prompt`, `Stop`, …) y
`[[ui.notifications.hooks]]`. Ambos exigen que un comando externo alcance a
Speell (IPC propio). Backlog.

## Agy — `.bell` (campana, requiere activación)

- Docs oficiales de Antigravity (settings, tab CLI): la clave `notifications`
  de `~/.gemini/antigravity-cli/settings.json` — "triggers a system desktop
  notification and a terminal bell chime when a long-running task completes
  or requires your attention". Default `false`; el `settings.json` real no
  trae la clave.
- La campana llega como `GHOSTTY_ACTION_RING_BELL`, presente en el header del
  pin junto a `DESKTOP_NOTIFICATION` y `COMMAND_FINISHED`. Se atrapa con el
  mismo `handleAction`. Regla: la campana solo es aviso en una tab de agente
  — una shell también toca el BEL (`tput bel`) y eso no lo es.
- Activación: explícita, desde la configuración de Speell (botón que escribe
  la clave documentada con merge conservador del JSON). Nunca automática:
  el archivo es config de otro producto.
- Los lifecycle hooks de Antigravity (`PreToolUse`, `PostToolUse`,
  `PreInvocation`, `PostInvocation`, `Stop`; docs `/docs/hooks/`) requieren
  un command-hook con IPC hacia Speell. Backlog.

## OpenCode 2 — `.none` (declarado)

- Ni el `--help` ni los docs (`opencode.ai/v2/docs/config/`) muestran OSC,
  campana o notificaciones del TUI.
- El canal real es un plugin TS (`opencode.ai/v2/docs/build/plugins/`):
  `ctx.permission.hook("evaluate", …)` para permisos y
  `ctx.event.subscribe()` para el stream de eventos. Instalar y mantener
  código nuestro dentro de la config del usuario es infraestructura propia;
  no entra en v1. Backlog.
- `opencode2 acp` (lead de la 0004) descartado para avisos: correría un
  servidor ACP en vez del TUI, y eso cambia el producto.
- Mientras tanto: `noticeSource = .none`, la tab no promete punto por turno
  (FLOW F5) y la configuración lo dice: "el CLI no ofrece canal".

## Tests

La decisión (qué hace un aviso según foco, preferencias y clase de tab) vive
en `Domain/NoticeRouter.swift`, pura, con dobles en
`Tests/SpeellTests/NoticeRouterTests.swift`: campana en shell = nada,
campana en agente = punto (y notificación solo sin foco), llave maestra y
tipos apagados dejan el punto pero callan la notificación. La prueba del plan
("un proceso falso que emite OSC 777 cambia el estado de la tab") queda
cubierta del lado decisional; el extremo surface→OSC es libghostty y va en la
prueba manual end-to-end de la fase.
