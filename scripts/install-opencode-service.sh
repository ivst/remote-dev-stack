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

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo/root: sudo $0" >&2
  exit 1
fi

if ! id "$DEV_USER" >/dev/null 2>&1; then
  echo "User $DEV_USER does not exist. Run bootstrap-host.sh first." >&2
  exit 1
fi

DEV_HOME="$(getent passwd "$DEV_USER" | cut -d: -f6)"
mkdir -p "$PROJECTS_DIR"
chown "$DEV_USER:$DEV_USER" "$PROJECTS_DIR"

OPENCODE_BIN="$(sudo -u "$DEV_USER" -H bash -lc 'command -v opencode 2>/dev/null || true')"
if [[ -z "$OPENCODE_BIN" && -x "$DEV_HOME/.opencode/bin/opencode" ]]; then
  OPENCODE_BIN="$DEV_HOME/.opencode/bin/opencode"
fi
if [[ -z "$OPENCODE_BIN" || ! -x "$OPENCODE_BIN" ]]; then
  echo "OpenCode executable not found for $DEV_USER. Run bootstrap-host.sh with INSTALL_OPENCODE=1." >&2
  exit 1
fi

install -d -m 700 /etc/remote-dev-stack
ENV_FILE=/etc/remote-dev-stack/opencode.env

if [[ -z "$OPENCODE_SERVER_PASSWORD" ]]; then
  if [[ -f "$ENV_FILE" ]] && grep -q '^OPENCODE_SERVER_PASSWORD=' "$ENV_FILE"; then
    OPENCODE_SERVER_PASSWORD="$(sed -n 's/^OPENCODE_SERVER_PASSWORD=//p' "$ENV_FILE" | head -n1)"
  else
    OPENCODE_SERVER_PASSWORD="$(openssl rand -base64 32 | tr -d '\n')"
  fi
fi

umask 077
cat > "$ENV_FILE" <<ENVEOF
OPENCODE_SERVER_USERNAME=$OPENCODE_USERNAME
OPENCODE_SERVER_PASSWORD=$OPENCODE_SERVER_PASSWORD
ENVEOF
chmod 600 "$ENV_FILE"

cat > /etc/systemd/system/opencode.service <<UNIT
[Unit]
Description=OpenCode remote development server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$DEV_USER
Group=$DEV_USER
Environment=HOME=$DEV_HOME
EnvironmentFile=$ENV_FILE
WorkingDirectory=$PROJECTS_DIR
ExecStart=$OPENCODE_BIN serve --hostname 127.0.0.1 --port $OPENCODE_PORT
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now opencode

sleep 1
systemctl --no-pager --full status opencode || true

echo
echo "OpenCode service installed."
echo "URL on host: http://127.0.0.1:$OPENCODE_PORT"
echo "Credentials: $ENV_FILE (mode 0600; password not printed)"
echo "WorkingDirectory: $PROJECTS_DIR"
