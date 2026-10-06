# 0003 — Contrato de Grok

Fecha: 2026-10-06. Estado: verificado contra el binario.

## Con qué se verificó

`grok` 1.0.46 (`grok version`), el del PATH del usuario. Nada sale de memoria: cada flag viene de `--help` del binario o de una corrida real.

| Uso del adaptador | Comando | Fuente |
|---|---|---|
| listar hilos de una carpeta | `grok sessions list -n 20` | `grok sessions list --help` + corrida real (es cwd-scoped: desde otra carpeta responde `No sessions found.`) |
| hilo nuevo, con id conocido | `grok --session-id <uuid>` | `grok --help` |
| retomar hilo concreto | `grok --resume <id>` | `grok --help` |
| último de la carpeta | `grok -c` | `grok --help` |

## Desviaciones del TRD, con motivo

1. **`launch(cwd, sessionId)` en vez de `launch(cwd)`.** `--session-id` deja que Speell proponga el id de la conversación nueva ("must be a valid UUID and must not already exist under the target session directory"). Así el puntero nace fiable y la tab es `exact` desde el arranque, sin leer el store del agente para descubrir el id después.
2. **`Command` es binario + args + cwd**, sin env. Hoy ningún adaptador necesita variables propias y libghostty lanza la surface con el entorno del usuario. Cuando haga falta se añadirá con `env_vars` del surface config, no antes.
3. **`observe(tab)` todavía no existe**: sin hooks no hay nada que observar. Llega en la fase 4.

## Lo que el CLI no da

`grok sessions list` no tiene `--json` y trunca el título al ancho de la terminal (`COLUMNS` no lo cambia cuando no hay TTY). Se parsea el UUID inicial, que es estable, y el título se usa como preview. Si el CLI cambia el formato, el parser devuelve lista vacía y la UI degrada a "hilo nuevo / último de esta carpeta" (UX F2): no rompe nada.

## Verificado de punta a punta

Con una tab de agente sembrada en `~/Library/Application Support/Speell/tabs.json` (`agent: grok`, `resumeQuality: exact`, un id real) y una carpeta desechable:

- La app arranca y en la tab corre `grok --resume 01a1115e-e659-7542-8878-4f88be486a2e` (argv visible en `ps`), con el cwd de la tab.
- El log del propio grok (`~/.grok/logs/unified.jsonl`) registra `session loaded` con ese `sid`, y no se crea ninguna sesión nueva en esa carpeta.
- Al salir, la app y los procesos de sus tabs mueren: sin huérfanos.

## Sin verificar

- `--session-id` para sesión nueva no se pudo correr de punta a punta: el TUI de grok no arranca sin TTY (`Device not configured`). Queda verificado por `--help` y por tests. Un `--resume` de un id inexistente arranca una sesión nueva en silencio, así que una tab `exact` cuyo hilo nunca llegó a existir se comporta como nueva.
- `grok` no expone hooks de permiso/fin: la tab queda sin aviso hasta la fase 4.
