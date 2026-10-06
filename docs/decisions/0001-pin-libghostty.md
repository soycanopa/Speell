# 0001 — Pin de libghostty

Fecha: 2026-10-05. Estado: decidido.

## Contexto

La Fase 0 necesita el xcframework de libghostty. El TRD pide un pin explícito (nunca `latest`) y fija el comando de build:

```bash
zig build -Demit-xcframework=true -Dxcframework-target=native \
  -Demit-macos-app=false -Doptimize=ReleaseFast
```

## Decisión

- **Ghostty**: commit `c3203ea4b169a18eb2ccfe92847e426d8afea858` (`1.3.2-dev`, rama `main`).
- **zig**: `0.16.0`.

## Por qué no el tag v1.3.1

v1.3.1 declara `minimum_zig_version = "0.15.2"`. En esta máquina zig 0.15.2 no enlaza **nada**, ni un hello world:

```
$ zig run hello.zig
error: undefined symbol: _abort
error: undefined symbol: _sigaction
```

El fallo está en el propio build runner de zig (`build_zcu.o`), no en código de Ghostty, y se reproduce con el SDK de macOS 26.5 y con el 27, con CommandLineTools y con Xcode. zig 0.16.0 y 0.17.0 enlazan sin problema.

El tag v1.3.1 tampoco compila con zig 0.16.0:

```
src/build/Config.zig:64:17: error: root source file struct 'process' has no member named 'EnvMap'
src/build/zig.zig:13:9: error: Your Zig version v0.16.0 does not meet the required build version of v0.15.2
```

`main` ya declara `minimum_zig_version = "0.16.0"`, que es el zig que sí funciona aquí.

## Desviación del comando del TRD

Se añade `-Di18n=false`. Sin ese flag, el paso de recursos instala las traducciones de Ghostty y aborta con `run msgfmt failure: FileNotFound` cuando no hay gettext en el sistema. Speell no embarca las traducciones de Ghostty, así que no se instalan. La alternativa era exigir `brew install gettext` para cada build.

## Consecuencias

- El pin es un commit de `main`, no un release. Sigue siendo inmutable y `Scripts/build-libghostty.sh` verifica el SHA antes de compilar.
- Subir el pin es un cambio propio: editar `Vendor/ghostty.pin`, correr el script y commitear el hash nuevo.
- Cuando exista un release de Ghostty con `minimum_zig_version >= 0.16.0`, se mueve el pin a ese tag y se borra este rodeo.

## Verificación

- `Scripts/build-libghostty.sh` genera `Vendor/GhosttyKit.xcframework` y escribe `Vendor/GhosttyKit.xcframework.sha256`.
- `Scripts/build-libghostty.sh --verify` compara el artefacto presente con el hash commiteado.
