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
OPENCODE_USERNAME="${OPENCODE_USERNAME:-opencode}"
OPENCODE_SERVER_PASSWORD="${OPENCODE_SERVER_PASSWORD:-}"
ENV_FILE=/etc/remote-dev-stack/opencode.env

if [[ -z "$OPENCODE_SERVER_PASSWORD" && -r "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [[ -z "${OPENCODE_SERVER_PASSWORD:-}" ]]; then
  read -rsp 'OpenCode password: ' OPENCODE_SERVER_PASSWORD
  echo
fi

found=0
for dir in "$PROJECTS_DIR"/*; do
  [[ -d "$dir/.git" ]] || continue
  found=1
  echo "Registering: $dir"
  curl -fsS -G \
    -u "$OPENCODE_USERNAME:$OPENCODE_SERVER_PASSWORD" \
    --data-urlencode "directory=$dir" \
    "http://127.0.0.1:$OPENCODE_PORT/project/current" >/dev/null
  echo "  OK"
done

if [[ "$found" == "0" ]]; then
  echo "No Git repositories found under $PROJECTS_DIR"
fi
