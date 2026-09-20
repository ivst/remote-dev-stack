#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$ROOT_DIR/.env"; set +a
fi

DEV_USER="${DEV_USER:-developer}"
OPENCODE_INSTALL_URL="${OPENCODE_INSTALL_URL:-https://opencode.ai/v2/install}"
OPENCODE_MAJOR_VERSION="${OPENCODE_MAJOR_VERSION:-2}"

extract_semver() {
  grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1
}

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo/root: sudo $0" >&2
  exit 1
fi

if ! id "$DEV_USER" >/dev/null 2>&1; then
  echo "User $DEV_USER does not exist." >&2
  exit 1
fi

DEV_HOME="$(getent passwd "$DEV_USER" | cut -d: -f6)"
OLD_VERSION_RAW="$(sudo -u "$DEV_USER" -H bash -lc '
  if command -v opencode >/dev/null 2>&1; then opencode --version 2>/dev/null || true;
  elif [[ -x "$HOME/.opencode/bin/opencode" ]]; then "$HOME/.opencode/bin/opencode" --version 2>/dev/null || true;
  fi
')"
OLD_VERSION="$(printf '%s\n' "$OLD_VERSION_RAW" | extract_semver || true)"

echo "Current OpenCode: ${OLD_VERSION_RAW:-not found}"
echo "Target: OpenCode V$OPENCODE_MAJOR_VERSION"
echo "Installer: $OPENCODE_INSTALL_URL"
echo
echo "WARNING: no backup will be created."

if systemctl cat opencode >/dev/null 2>&1; then
  systemctl stop opencode
fi

sudo -u "$DEV_USER" -H env OPENCODE_INSTALL_URL="$OPENCODE_INSTALL_URL" bash -lc   'curl -fsSL "$OPENCODE_INSTALL_URL" | bash'

OPENCODE_BIN="$DEV_HOME/.opencode/bin/opencode"
if [[ ! -x "$OPENCODE_BIN" ]]; then
  OPENCODE_BIN="$(sudo -u "$DEV_USER" -H bash -lc 'command -v opencode 2>/dev/null || true')"
fi

if [[ -z "$OPENCODE_BIN" || ! -x "$OPENCODE_BIN" ]]; then
  echo "OpenCode executable not found after V2 installation." >&2
  exit 1
fi

NEW_VERSION_RAW="$(sudo -u "$DEV_USER" -H "$OPENCODE_BIN" --version)"
NEW_VERSION="$(printf '%s\n' "$NEW_VERSION_RAW" | extract_semver || true)"
NEW_MAJOR="${NEW_VERSION%%.*}"

if [[ -z "$NEW_VERSION" || "$NEW_MAJOR" != "$OPENCODE_MAJOR_VERSION" ]]; then
  echo "Unexpected OpenCode version after install: $NEW_VERSION_RAW" >&2
  echo "Service was not restarted." >&2
  exit 1
fi

echo "Installed OpenCode: $NEW_VERSION_RAW"

if systemctl cat opencode >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl restart opencode
  sleep 1
  systemctl --no-pager --full status opencode || true
else
  echo "No opencode.service found. Install it with:"
  echo "  sudo $ROOT_DIR/scripts/install-opencode-service.sh"
fi

echo
echo "Migration complete."
echo "No backup was created."
echo "V1 and V2 share the main configuration locations."
echo "V1 plugins and integrations using the V1 server API must be migrated separately."
