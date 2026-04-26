# plantilla-flow

Base DevSecOps template for distributable tools, with SSOT versioning driven by Git tags.

## What's included
- `.github/workflows/release.yaml` (GitHub Actions)
- `.gitea/workflows/release.yaml` (Gitea Actions)
- `publish.sh` — commit + push + tag + push tag
- `build.sh` — example build script (overwritten by the launcher on bootstrap)
- `build-templates/` — per-language build script templates
- `BUILD_CONTRACT.md` — mandatory build rules every `build.sh` must follow
- `CHANGELOG.md` — Keep a Changelog format
- `runners_setup/` — scripts and guide to provision self-hosted runners
- `.gitignore` — strict binary exclusion rules

## Operational rules
- The version comes **only** from the Git tag (`vX.Y.Z`).
- The workflow injects `APP_VERSION` into `build.sh` at build time.
- The workflow also injects `BUILD_LINUX` and `BUILD_WINDOWS` (0 or 1) into `build.sh`.
- `build.sh` must deposit all release artifacts under `dist/`.
- Linux ELF binaries are packaged into a `.deb` (via FPM) and published alongside the raw binary; `.exe` files are published as-is.
- If `CHANGELOG.md` has no `## [X.Y.Z]` section matching the tag, the release job fails.
- Source code lives in `./code/`. The launcher-generated `build.sh` does `cd code` before compiling.

## Execution matrix (release.yaml)

| Case | Condition | Jobs executed |
|------|-----------|---------------|
| 1 | Cross-compile language + `BUILD_LINUX=1` + `BUILD_WINDOWS=1` | `build_cross` (single Linux job, produces both binaries) |
| 2 | Cross-compile language + only one platform enabled | `build_cross` with the other platform's flag set to 0 |
| 3 | Native-only language + both platforms enabled | `build_native_linux` + `build_native_windows` |
| 4 | Native-only language + only one platform enabled | The corresponding native job only |

This matrix applies identically on GitHub Actions and Gitea Actions.

## Supported languages (`PROJECT_LANG`)

`go` · `python` · `rust` · `node` · `java` · `dotnet` · `ruby` · `php` · `c` · `cpp` · `script`

## Bootstrapping a new project manually
1. Copy the contents of this folder to your new repo (or use the launcher).
2. Set `PROJECT_LANG`, `BUILD_LINUX`, `BUILD_WINDOWS` in the `plan` job of the workflow.
3. Copy a template from `build-templates/supports-crosscompiling/` or `build-templates/no-crosscompiling/` to `build.sh` and adapt the project variables.
4. Move your source code into `./code/`.
5. Review `BUILD_CONTRACT.md`.
6. Add `## [1.0.0] - YYYY-MM-DD` to `CHANGELOG.md`.
7. Run `./publish.sh v1.0.0 "Initial release"`.

## Platform notes
- On GitHub, the active workflow file is `.github/workflows/release.yaml`.
- On Gitea, the active workflow file is `.gitea/workflows/release.yaml`.
- Do not mix GitHub and Gitea workflow files in the same active provider. The launcher removes the folder that does not apply during bootstrap.
