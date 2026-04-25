#!/usr/bin/env bash
# publish.sh — manual release path for projects that don't use the launcher.
#
# Usage:
#   ./publish.sh vX.Y.Z "mensaje"
#   ./publish.sh vX.Y.Z "mensaje" tool-name
#
# The optional third argument sets the binary filename by rewriting
# APP_NAME's default in build.sh before committing. Equivalent to what
# the launcher's "Tool name" field does. Skip it if you've already set
# APP_NAME in build.sh manually or via CI env vars.
set -euo pipefail

VERSION="${1:-}"
MESSAGE="${2:-}"
BINARY_NAME="${3:-}"

if [[ -z "$VERSION" || -z "$MESSAGE" ]]; then
  echo "Uso: ./publish.sh vX.Y.Z \"mensaje\" [tool-name]"
  echo ""
  echo "  vX.Y.Z       version semver con prefijo v (obligatorio)"
  echo "  mensaje      texto del commit y del tag (obligatorio)"
  echo "  tool-name    binary filename, lowercased a-z/0-9/-/_ (opcional)"
  echo ""
  echo "Si omites tool-name, build.sh usara el APP_NAME que tenga ya."
  exit 1
fi

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: version invalida. Usa formato vX.Y.Z (ej: v1.2.0)."
  exit 1
fi

if [[ -n "$BINARY_NAME" && ! "$BINARY_NAME" =~ ^[a-z0-9_-]+$ ]]; then
  echo "ERROR: tool-name solo admite [a-z0-9_-]. Recibido: '$BINARY_NAME'"
  exit 1
fi

TAG_VERSION="${VERSION#v}"
if ! grep -Eq "^## \[$TAG_VERSION\]( - .*)?$" CHANGELOG.md; then
  echo "ERROR: no existe la seccion ## [$TAG_VERSION] en CHANGELOG.md"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: este directorio no es un repositorio git."
  exit 1
fi

if git rev-parse "$VERSION" >/dev/null 2>&1; then
  echo "ERROR: el tag $VERSION ya existe."
  exit 1
fi

if [[ ! -f build.sh ]]; then
  echo "ERROR: no se encontro build.sh en $PWD."
  exit 1
fi

# Optional: rewrite APP_NAME default in build.sh.
# Matches the launcher's behaviour: replace the value between :- and the
# closing brace inside APP_NAME="${APP_NAME:-...}". Anything already there
# (auto-detect command or a previous explicit name) gets overwritten.
if [[ -n "$BINARY_NAME" ]]; then
  if ! grep -q '^APP_NAME="\${APP_NAME:-' build.sh; then
    echo "ERROR: build.sh no tiene la linea APP_NAME=\"\${APP_NAME:-...}\""
    echo "       No puedo inyectar tool-name automaticamente. Editalo a mano."
    exit 1
  fi
  awk -v name="$BINARY_NAME" '
    /^APP_NAME="\$\{APP_NAME:-/ && !done {
      sub(/:-[^}]+\}/, ":-" name "}")
      done = 1
    }
    { print }
  ' build.sh > build.sh.tmp && mv build.sh.tmp build.sh
  chmod +x build.sh
  echo "[+] APP_NAME en build.sh fijado a '$BINARY_NAME'"
fi

forbidden_re='(^dist/|\.exe$|\.deb$|\.o$|\.so$|(^|/)a\.out$|(^|/)my_tool$|(^|/)cve-parser$|\.bin$|\.out$)'

# Preflight: permitir archivos fuente no trackeados, bloquear solo artefactos prohibidos.
if git ls-files --others --exclude-standard | grep -E "$forbidden_re" >/dev/null 2>&1; then
  echo "ERROR: hay artefactos/binarios no trackeados que 'git add .' incluiria:"
  git ls-files --others --exclude-standard | grep -E "$forbidden_re"
  echo "Limpia esos archivos o anadelos al .gitignore antes de publicar."
  exit 1
fi

if git ls-files | grep -E "$forbidden_re" >/dev/null 2>&1; then
  echo "ERROR: hay binarios/artefactos versionados en git (violan politica Cero Binarios)."
  echo "Limpia el index antes de publicar."
  exit 1
fi

git add .

if git diff --cached --quiet; then
  echo "ERROR: no hay cambios para commitear."
  exit 1
fi

git commit -m "Release $VERSION: $MESSAGE"
git push origin main

git tag -a "$VERSION" -m "$MESSAGE"
git push origin "$VERSION"

echo "OK: release $VERSION publicada."
