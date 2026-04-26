#!/usr/bin/env bash
# publish.sh — manual release path for projects that don't use the launcher.
#
# Usage:
#   ./publish.sh vX.Y.Z "commit message"
#   ./publish.sh vX.Y.Z "commit message" tool-name
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
  echo "Usage: ./publish.sh vX.Y.Z \"commit message\" [tool-name]"
  echo ""
  echo "  vX.Y.Z          semver tag with v prefix (required)"
  echo "  commit message  text used for the commit and the tag (required)"
  echo "  tool-name       binary filename, lowercase a-z/0-9/-/_ (optional)"
  echo ""
  echo "If tool-name is omitted, build.sh uses whatever APP_NAME is already set to."
  exit 1
fi

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: invalid version. Use the format vX.Y.Z (e.g. v1.2.0)."
  exit 1
fi

if [[ -n "$BINARY_NAME" && ! "$BINARY_NAME" =~ ^[a-z0-9_-]+$ ]]; then
  echo "ERROR: tool-name only allows [a-z0-9_-]. Got: '$BINARY_NAME'"
  exit 1
fi

TAG_VERSION="${VERSION#v}"
if ! grep -Eq "^## \[$TAG_VERSION\]( - .*)?$" CHANGELOG.md; then
  echo "ERROR: no ## [$TAG_VERSION] section found in CHANGELOG.md"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: this directory is not a git repository."
  exit 1
fi

if git rev-parse "$VERSION" >/dev/null 2>&1; then
  echo "ERROR: tag $VERSION already exists."
  exit 1
fi

if [[ ! -f build.sh ]]; then
  echo "ERROR: build.sh not found in $PWD."
  exit 1
fi

# Optional: rewrite APP_NAME default in build.sh.
# Matches the launcher's behaviour: replace the value between :- and the
# closing brace inside APP_NAME="${APP_NAME:-...}". Anything already there
# (auto-detect command or a previous explicit name) gets overwritten.
if [[ -n "$BINARY_NAME" ]]; then
  if ! grep -q '^APP_NAME="\${APP_NAME:-' build.sh; then
    echo "ERROR: build.sh does not have the line APP_NAME=\"\${APP_NAME:-...}\""
    echo "       Cannot inject tool-name automatically. Edit it manually."
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
  echo "[+] APP_NAME in build.sh set to '$BINARY_NAME'"
fi

forbidden_re='(^dist/|\.exe$|\.deb$|\.o$|\.so$|(^|/)a\.out$|(^|/)my_tool$|(^|/)cve-parser$|\.bin$|\.out$)'

if git ls-files --others --exclude-standard | grep -E "$forbidden_re" >/dev/null 2>&1; then
  echo "ERROR: untracked build artifacts found that 'git add .' would include:"
  git ls-files --others --exclude-standard | grep -E "$forbidden_re"
  echo "Remove those files or add them to .gitignore before publishing."
  exit 1
fi

if git ls-files | grep -E "$forbidden_re" >/dev/null 2>&1; then
  echo "ERROR: tracked binary/artifact files found (violates the Zero-Binaries policy)."
  echo "Remove them from the index before publishing."
  exit 1
fi

git add .

if git diff --cached --quiet; then
  echo "ERROR: nothing to commit."
  exit 1
fi

git commit -m "Release $VERSION: $MESSAGE"
git push origin main

git tag -a "$VERSION" -m "$MESSAGE"
git push origin "$VERSION"

echo "OK: release $VERSION published."
