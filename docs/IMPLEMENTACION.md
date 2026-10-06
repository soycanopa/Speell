# Implementación — Speell

Estado: orden de construcción. Fecha: 2026-10-05.
No se salta el spike. No se implementa un adaptador "de paso" mientras el shell no restaura.

## Fase 0 — Spike de surface

Una ventana AppKit. Un `NSView`. Una surface libghostty. Shell interactivo en `$HOME`. Cerrar la ventana mata el shell.

Pin del commit de Ghostty escrito en el repo. xcframework generado con el comando del TRD, no commiteado si pesa: script de fetch/build y hash.

Salida: se siente como terminal. Si el teclado, el resize o el fondo fallan, no hay fase 1.

## Fase 1 — Proyecto y tab shell

Sidebar SwiftUI. Añadir y quitar carpeta. Varias tabs shell. Persistir proyectos y tabs. Restaurar cwd. Scrollback no se promete.

Prueba: quit y relaunch, misma carpeta, mismo número de tabs, procesos nuevos.

## Fase 2 — Adaptador Grok

`list` / `launch` / `resume` / `continueLatest` contra el `grok` del PATH. Tab de agente. Calidad exacta vs última, visible. Sin hook todavía.

Prueba manual con una sesión real, más un test del adaptador con un binario falso que imprime `--help` y un id fijo. El test no llama a la red ni exige login.

## Fase 3 — OpenCode 2 y Agy

Mismo interfaz. OpenCode 2 usa su directorio propio (`~/.local/share/opencode2`), no el de `opencode`. Agy puede quedar con lista vacía y solo `-c` / `--conversation` si no hay listado estable. Eso se documenta en el adaptador, no se parchea leyendo archivos no documentados.

No se abre un cuarto agente.

## Fase 4 — Avisos

Por agente, en orden: hook documentado, si no OSC 9/777, si no `hooks: none`. Badge, toast, notificación que enfoca. Permiso de notificaciones en el primer aviso.

Prueba: un proceso falso que emite OSC 777 cambia el estado de la tab. No hace falta un agente real para ese test.

## Fase 5 — Cierre limpio

Quit espera hijos. Timeout documentado. Sin servidores sueltos. Recorrer F0–F8 de `FLOW.md` a mano y marcar la lista.

## Commits

Ramas `feature/<fase>`. Un commit, un cambio. Mensaje `type(scope): summary`.

Ejemplos: `feat(terminal): embed libghostty surface in nsview`, `feat(agents): resume grok session by id`, `docs(flow): mark F3 restore as specified`.

Prohibido un commit "MVP". Prohibido colgar la lógica nueva en un archivo que ya hace otra cosa: el archivo nuevo entra en el mismo commit que el cambio.

## Releases

Una fase terminada, un release **completo**, no un pre-release: tag anotado `vX.Y.Z` sobre el merge de la fase en `main`, y notas con qué entra, qué se verificó y cómo se construye.

No se publica la fase a medias ni se corta el tag con trabajo de la fase siguiente a medio camino. Las notas dicen lo que falta y lo que no se pudo verificar, no lo esconden.

## Módulos en cada fase

Cada fase nace en su carpeta del TRD. La fase 0 no crea un `AppDelegate` con el shell, el resize y el kill dentro. La fase 2 añade `Agents/GrokAdapter.swift` y tests, no un `if grok` en la vista. Si un archivo pasa el tope de la sección Arquitectura modular, partirlo es parte de la tarea, no un refactor futuro.

## Pruebas

- Adaptadores y persistencia, sí, con dobles.
- Surface Metal, no en CI headless. Smoke manual en el spike y en la fase 5.
- Un test que falla se lee. No se borra, no se ignora, no se afloja el assert para ver verde.
- Si el mismo enfoque falla dos veces, se para y se escribe qué se intentó.

## Definición de hecho del MVP

- [ ] Spike de shell libghostty cerrado limpio
- [ ] Proyectos y tabs shell sobreviven al relaunch
- [ ] Grok, OpenCode 2 y Agy lanzan y retoman con el flag real, o degradan a `-c` dicho en la UI
- [ ] Aviso real o `hooks: none` explícito por agente
- [ ] Notificación enfoca la tab
- [ ] F0–F8 recorridos
- [ ] Pin de Ghostty y binarios esperados escritos en el repo
- [ ] UI y dominio en módulos distintos; ningún archivo nuevo mezcla vista, resume y notify

## Backlog que no se cuela

Splits, temas, transcript propio, Windows, cuarto agente, proceso vivo entre launches, paleta de comandos, sync.
