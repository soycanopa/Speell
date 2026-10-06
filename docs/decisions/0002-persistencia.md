# 0002 — Persistencia local

Fecha: 2026-10-05. Estado: decidido.

## Contexto

El TRD deja elegir entre JSON y SQLite de una tabla ("da igual en el spike; se elige en la fase 1 y no se migran los dos"). Nada de nube.

## Decisión

JSON en `~/Library/Application Support/Speell/`:

- `projects.json`: proyectos fijados y cuál está activo.
- `tabs.json`: tabs con su `cwd` y su puntero de sesión.

Cada store es dueño de su archivo y lo reescribe entero, de forma atómica (`Data.write(options: .atomic)`).

## Por qué

- El estado es pequeño (decenas de filas) y de un solo escritor.
- Inspeccionable y diffeable a mano, sin dependencias nuevas.
- SQLite no aporta nada aquí: no hay consultas, ni concurrencia, ni volumen.

## Consecuencias

- El esquema queda escrito por `Codable`. Los campos nuevos se añaden opcionales, así un archivo viejo sigue decodificando.
- La carpeta del store es inyectable (`JSONStore(directory:)`), y los tests usan un directorio temporal en vez de la Application Support del usuario.
- Si algún día hace falta migrar, se migra una vez y se documenta. No se mantienen los dos formatos.
