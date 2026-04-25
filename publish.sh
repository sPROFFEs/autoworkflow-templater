#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
MESSAGE="${2:-}"

if [[ -z "$VERSION" || -z "$MESSAGE" ]]; then
  echo "Uso: ./publish.sh vX.Y.Z \"mensaje\""
  exit 1
fi

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: version invalida. Usa formato vX.Y.Z (ej: v1.2.0)."
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

forbidden_re='(^dist/|\.exe$|\.deb$|\.o$|\.so$|(^|/)a\.out$|(^|/)my_tool$|(^|/)cve-parser$|\.bin$|\.out$)'

# Preflight: permitir archivos fuente no trackeados, bloquear solo artefactos prohibidos.
if git ls-files --others --exclude-standard | grep -E "$forbidden_re" >/dev/null 2>&1; then
  echo "ERROR: hay artefactos/binarios no trackeados que `git add .` incluiria:"
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
