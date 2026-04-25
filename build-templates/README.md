# build-templates

Plantillas de `build.sh` por lenguaje para adaptar en cada proyecto.

## Estructura
- `supports-crosscompiling/`: lenguajes/estrategias que permiten generar Linux y Windows desde un mismo job (segun toolchain disponible).
- `no-crosscompiling/`: lenguajes/estrategias que necesitan runner por plataforma para generar ambos artefactos.

## Comportamiento por defecto
- Todas las plantillas vienen con `BUILD_LINUX=1` y `BUILD_WINDOWS=1`.
- Cada script separa bloques por plataforma con marcadores:
  - `===== LINUX BUILD START/END =====`
  - `===== WINDOWS BUILD START/END =====`
- Si solo quieres una plataforma, tienes dos opciones:
  1. Borrar el bloque de la otra plataforma.
  2. Mantenerlo y ejecutar con `BUILD_LINUX=0` o `BUILD_WINDOWS=0`.

## Uso
1. Copia la plantilla adecuada a `./build.sh`.
2. Ajusta variables (`APP_NAME`, `ENTRY_POINT`, etc.).
3. Revisa bloques Linux/Windows y elimina lo que no quieras.
4. Asegura salida final en `dist/`.
5. Verifica contrato en `../BUILD_CONTRACT.md`.

## Nota importante
En algunos stacks (ej: Python + PyInstaller) no hay cross-compilado oficial Linux -> Windows dentro de la misma ejecución. En esos casos, la plantilla falla con mensaje claro para forzar:
- runner Windows para `.exe`, o
- desactivar `BUILD_WINDOWS`.
