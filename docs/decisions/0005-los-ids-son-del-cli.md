# 0005 — Los ids de sesión son del CLI

Fecha: 2026-10-06. Estado: decisión del propietario, implementada.

## La decisión

Speell no propone ids de sesión. La conversación nueva corre el CLI a secas y
el id lo genera y guarda el propio agente. Speell solo guarda punteros a ids
que el CLI ya registró (los que devuelve `list`), o marca la tab como sin
puntero (`.fresh`), que al restaurar se convierte en "último de la carpeta"
(FLOW F3).

Anula la desviación 1 de docs/decisions/0003 (`launch(cwd, sessionId)` con id
propuesto por Speell) y el `canPinSessionId` que la fase 3 añadió: el contrato
volvió a `launch(cwd)`.

## Por qué

La propuesta de id era una apuesta a que cada CLI aceptaría un id ajeno. La
verificación de punta a punta de la fase 3 la perdió:

- opencode2 v2.0.22 rechaza cualquier id que no empiece con `ses`:
  `Error: Expected a string starting with "ses" at ["sessionID"]` (corrida
  real con un UUID de Speell, 2026-10-06).
- grok muere en la app al lanzarle un id propuesto: el proceso desaparece y la
  tab queda sin TUI (observado en las mismas sesiones; 0003 ya anotaba que
  `--session-id` nunca se verificó de punta a punta).

El modelo correcto es el que ya usaba el resto del contrato: el transcript lo
guarda el CLI, el puntero lo da su `list`, y Speell no inventa estado.

## Consecuencias

- Tab nueva de agente: siempre sin `sessionId`, `resumeQuality: .fresh`, y
  corre `launch` (CLI a secas).
- Al restaurar, una tab `.fresh` pregunta al `list` del adaptador: con
  sesiones en la carpeta pasa a `.latestInDir` (`continueLatest`); sin ellas
  se queda `.fresh` y corre `launch` — `continueLatest` sobre una carpeta sin
  sesiones es un error garantizado del CLI (grok v1.0.46:
  "No session found for current directory", F6). La fuente de la decisión es
  el listado del propio CLI, nunca scrollback.
- `resume` solo recibe ids que salieron de `list` del propio CLI.
- Los punteros que la fase 3 dejó con UUIDs propuestos son basura conocida: al
  restaurar pueden fallar por F6 (se muestra la salida del CLI; Speell no
  borra el puntero sola). El usuario puede pasar esas tabs a "última" o
  cerrarlas.
