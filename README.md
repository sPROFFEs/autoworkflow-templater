# plantilla-flow

Plantilla base DevSecOps para herramientas de pentesting con versionado SSOT por Git tag.

## Incluye
- `.github/workflows/release.yaml` (GitHub Actions)
- `.gitea/workflows/release.yaml` (Gitea Actions)
- `publish.sh` (commit + push + tag + push tag)
- `build.sh` (ejemplo de contrato por `APP_VERSION`)
- `build-templates/` (plantillas por lenguaje)
- `BUILD_CONTRACT.md` (reglas obligatorias de build)
- `CHANGELOG.md` (Keep a Changelog)
- `.gitignore` estricto contra binarios

## Reglas operativas
- La version sale solo del tag (`vX.Y.Z`).
- El workflow inyecta `APP_VERSION` a `build.sh`.
- El workflow inyecta tambien `BUILD_LINUX` y `BUILD_WINDOWS` (0/1) a `build.sh`.
- `build.sh` debe dejar artefactos en `dist/`.
- Linux ELF se empaqueta en `.deb` (FPM), `.exe` se publica crudo.
- Si no existe `## [X.Y.Z]` en `CHANGELOG.md`, la release falla.
- El codigo de la herramienta vive en `./code/`. El `build.sh` generado por el launcher hace `cd code` antes de compilar.

## Matriz de ejecucion (release.yaml)
- Caso 1: lenguaje con cross-compiling + `BUILD_LINUX=1` y `BUILD_WINDOWS=1`.
Se ejecuta un solo job Linux (`build_cross`) y genera ambos artefactos si el toolchain lo soporta.
- Caso 2: lenguaje con cross-compiling + solo una plataforma activa.
Se ejecuta `build_cross` con la plataforma desactivada en `BUILD_*`.
- Caso 3: lenguaje sin cross-compiling + ambas plataformas activas.
Se ejecutan dos jobs nativos: `build_native_linux` + `build_native_windows`.
- Caso 4: lenguaje sin cross-compiling + solo una plataforma activa.
Se ejecuta solo el job nativo correspondiente.

Esta matriz aplica igual en GitHub Actions y en Gitea Actions.

## Lenguajes soportados (selector de workflow)
Variable: `PROJECT_LANG`

Valores permitidos:
- `go`
- `python`
- `rust`
- `node`
- `java`
- `dotnet`
- `ruby`
- `php`

## Alta de nuevo proyecto desde plantilla
1. Copia el contenido de esta carpeta al repo nuevo (o usa el launcher).
2. Ajusta `PROJECT_LANG`, `BUILD_LINUX`, `BUILD_WINDOWS` en el job `plan` del workflow.
3. Copia una base desde `build-templates/supports-crosscompiling/` o `build-templates/no-crosscompiling/` a `build.sh` y adapta variables del proyecto.
4. Mueve el codigo fuente a `./code/`.
5. Verifica `BUILD_CONTRACT.md`.
6. Actualiza `CHANGELOG.md` con `## [1.0.0] - YYYY-MM-DD`.
7. Ejecuta `./publish.sh v1.0.0 "Initial release"`.

## Notas por plataforma
- En GitHub usa `.github/workflows/release.yaml`.
- En Gitea usa `.gitea/workflows/release.yaml`.
- No mezcles acción de release de Gitea en GitHub ni viceversa. El launcher elimina la carpeta del provider que no aplica al bootstrap.
