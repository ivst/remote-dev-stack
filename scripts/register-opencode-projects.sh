#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$ROOT_DIR/.env"; set +a
fi

DEV_USER="${DEV_USER:-developer}"
PROJECTS_DIR="${PROJECTS_DIR:-/home/$DEV_USER/projects}"
OPENCODE_PORT="${OPENCODE_PORT:-4096}"

echo "OpenCode V2 does not use the V1 /project/current registration API."
echo "Git repositories discovered under: $PROJECTS_DIR"
echo

found=0
for dir in "$PROJECTS_DIR"/*; do
  [[ -d "$dir/.git" ]] || continue
  found=1
  printf '%s\n' "$dir"
done

if [[ "$found" == "0" ]]; then
  echo "No Git repositories found."
  exit 0
fi

echo
echo "Open a project with the V2 client, for example:"
echo "  cd $PROJECTS_DIR/<project>"
echo "  export OPENCODE_SERVER_PASSWORD='...'"
echo "  opencode --server http://127.0.0.1:$OPENCODE_PORT"
