# Build Contract (Obligatorio)

`build.sh` puede variar por proyecto, pero debe cumplir este contrato para que el workflow no rompa.

## Entradas
- Variable `APP_VERSION` inyectada por CI desde el tag (`vX.Y.Z` -> `X.Y.Z`).
- Si `APP_VERSION` no existe (ejecucion local), usar fallback `dev-local`.

## Reglas obligatorias
1. Usar `set -euo pipefail`.
2. Crear `dist/` y dejar artefactos finales solo en `dist/`.
3. No hardcodear version en fuente. Inyectar `APP_VERSION` en build/empaquetado.
4. Salir con `exit 1` y mensaje claro si falta toolchain o no hay artefactos.
5. Limpiar temporales si se generan.

## Salidas esperadas
- Linux: al menos 1 binario ELF en `dist/` si se quiere generar `.deb`.
- Windows: opcional `.exe` en `dist/`.

## Checklist rapida
- `./build.sh` crea `dist/`.
- Hay artefactos dentro de `dist/`.
- Si es Go/Rust/C/C++, existe ELF para Linux.
- No aparecen binarios fuera de `dist/`.
