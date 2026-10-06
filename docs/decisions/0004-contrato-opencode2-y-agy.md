# 0004 — Contrato de OpenCode 2 y Agy

Fecha: 2026-10-06. Estado: verificado contra los binarios.

## Con qué se verificó

`opencode2` v2.0.22 (`opencode2 --version` dice `opencode v2.0.22`; es opencode
v2 instalado como `opencode2`) y `agy` (sin versión imprimible en `--help`), los
del PATH del usuario. Nada sale de memoria: cada flag viene de `--help`, del
spec OpenAPI del propio binario (`opencode2 api GET /openapi.json` contra el
servicio de fondo) o de una corrida real.

| Uso del adaptador | Comando | Fuente |
|---|---|---|
| listar hilos de una carpeta | `opencode2 session list -n 20 --format json` | `opencode2 session list --help` + corrida real (cwd-scoped) |
| hilo nuevo, con id conocido | `opencode2 --session <id>` | `opencode2 --help`: "Session ID to continue, or to create if it does not exist" |
| retomar hilo concreto | `opencode2 --session <id>` | mismo flag |
| último de la carpeta | `opencode2 --continue` | `opencode2 --help` |
| retomar hilo concreto (Agy) | `agy --conversation <id>` | `agy --help`: "Resume a previous conversation by ID" |
| último de la carpeta (Agy) | `agy --continue` | `agy --help` |
| sesión nueva (Agy) | `agy` a secas | no hay flag para fijar id; el TUI abre conversación nueva |

Agy no tiene subcomando de sesiones: `list` es siempre vacío y el modal degrada
a "sesión nueva" (FLOW F2). Está declarado en el adaptador, no parcheado.

## Desviaciones de la fase 2, con motivo

1. **`canPinSessionId` en el protocolo.** Grok y OpenCode 2 aceptan fijar el id
   de una sesión nueva; Agy no. El controlador usa ese dato: una tab nueva de
   un adaptador sin pin nace `.fresh` sin puntero.
2. **Una tab recién creada corre `launch()`, no el rearmado de restore.** Hasta
   ahora toda tab nueva corría `resume()`, que para Grok funcionaba porque un
   `--resume` de id inexistente arranca nuevo (0003, "Sin verificar"). Para Agy
   eso es incorrecto: sin puntero caería en `--continue` y "nuevo" retomaría el
   último hilo (FLOW F2). Ahora el `launch` explícito crea la tab y el restore
   rearma con resume/continueLatest.
3. **Al restaurar, una tab `.fresh` se promueve a `.latestInDir`.** El proceso
   murió con la app: no hay hilo que recrear, queda el último de la carpeta, y
   la etiqueta de la tab ("última") dice lo que corre (FLOW F3).

## El store de OpenCode 2: contradicción con la regla del repo

La regla dice "OpenCode 2 no comparte store con `opencode`. Datos en
`~/.local/share/opencode2`". El binario hace otra cosa, con evidencia:

- Sonda con `HOME` temporal: `opencode2 session list` creó
  `$HOME/.local/share/opencode`, no `opencode2`.
- El store real `~/.local/share/opencode/` se actualiza hoy (db y wal con
  timestamps de esta sesión de pruebas).
- El `opencode` v1 existe aparte (shim de node en
  `~/.nvm/versions/node/v24.21.0/bin/opencode`), así que la colisión de
  directorio es entre dos CLIs ajenos a Speell.

Speell no toca ese store: el adaptador solo llama al CLI. Fijar `XDG_DATA_HOME`
para "cumplir" la regla aislaría las sesiones que Speell ve de las que el
usuario ve en su terminal, y eso rompe el producto. Se mantiene el default del
CLI **hasta que Carlos decida**; la regla de `AGENTS.md` queda en revisión.

## Bugs y límites observados del CLI

- `--standalone` aparece en el `--help` de `session list` pero el parser lo
  rechaza ("Unrecognized flag"); solo funciona a nivel raíz (opencode v2.0.22).
- El primer arranque del servicio de fondo en un `HOME` virgen tardó ~75 s.
  Por eso `list()` usa timeout de 10 s: en caliente responde en <0.1 s, y si
  se pasa, la lista queda vacía y el modal degrada.
- Los ids reales cumplen el patrón `^ses` del OpenAPI (`ses_…`). Speell propone
  un UUID propio: el `--help` dice que `-s` crea si no existe, pero **no está
  verificado de punta a punta** que acepte un id de otro formato. Si el primer
  uso real lo rechaza, el camino es `canPinSessionId = false` para opencode2,
  que ya degrada sin puntero.

## Sin verificar

- Lanzar el TUI de opencode2 o de agy de punta a punta desde Speell: ninguno de
  los dos arranca sin TTY en las sondas headless. Queda para la prueba manual
  de la fase (una sesión real por agente) antes del release.
- Que el título aparezca en el formato slim de `session list --format json`:
  las sesiones capturadas no lo tenían. El parser lo decodifica como opcional
  según `Session.Info` del OpenAPI del binario.
