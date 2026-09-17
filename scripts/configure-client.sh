#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$ROOT_DIR/.env"; set +a
fi

SSH_ALIAS="${SSH_ALIAS:-dev-vps}"
SSH_HOST="${SSH_HOST:-dev.example.com}"
SSH_PORT="${SSH_PORT:-22}"
SSH_USER="${SSH_USER:-developer}"
SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-~/.ssh/id_ed25519}"
CLIENT_PROJECT_DIR="${CLIENT_PROJECT_DIR:-/home/$SSH_USER/projects}"

if ! command -v ssh >/dev/null 2>&1; then
  echo "OpenSSH client is required." >&2
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
CONFIG="$HOME/.ssh/config"
touch "$CONFIG"
chmod 600 "$CONFIG"

START="# >>> remote-dev-stack:$SSH_ALIAS >>>"
END="# <<< remote-dev-stack:$SSH_ALIAS <<<"

TMP="$(mktemp)"
awk -v s="$START" -v e="$END" '
  $0 == s {skip=1; next}
  $0 == e {skip=0; next}
  !skip {print}
' "$CONFIG" > "$TMP"

cat >> "$TMP" <<EOF2

$START
Host $SSH_ALIAS
    HostName $SSH_HOST
    User $SSH_USER
    Port $SSH_PORT
    IdentityFile $SSH_IDENTITY_FILE
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
$END
EOF2

mv "$TMP" "$CONFIG"
chmod 600 "$CONFIG"

echo "Updated $CONFIG with host alias: $SSH_ALIAS"
echo "Test with: ssh $SSH_ALIAS"
echo
if command -v code >/dev/null 2>&1; then
  echo "VS Code detected. After connectivity is verified, you can run:"
  echo "  code --remote ssh-remote+$SSH_ALIAS $CLIENT_PROJECT_DIR"
else
  echo "VS Code CLI not found. Install VS Code + the official Remote - SSH extension."
fi

echo
echo "JetBrains: use Remote Development / Gateway -> SSH Connection -> $SSH_ALIAS"
echo "Project root: $CLIENT_PROJECT_DIR/<project-name>"
