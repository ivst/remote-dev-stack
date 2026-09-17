#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$ROOT_DIR/.env"; set +a
fi

DEV_USER="${DEV_USER:-developer}"
PROJECTS_DIR="${PROJECTS_DIR:-/home/$DEV_USER/projects}"
OPENCODE_PORT="${OPENCODE_PORT:-4096}"

ok()   { printf 'OK   %s\n' "$*"; }
warn() { printf 'WARN %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; }

echo "== System =="
printf 'Kernel: '; uname -r
printf 'Arch:   '; uname -m
printf 'CPUs:   '; nproc 2>/dev/null || true
free -h 2>/dev/null || true
df -h / 2>/dev/null || true
printf 'Swap:   '; swapon --show --noheadings 2>/dev/null | head -n1 || true

if command -v ldd >/dev/null 2>&1; then
  printf 'glibc:  '; ldd --version 2>&1 | head -n1
fi

echo
echo "== Account/layout =="
if id "$DEV_USER" >/dev/null 2>&1; then ok "user $DEV_USER exists"; else fail "user $DEV_USER missing"; fi
if [[ -d "$PROJECTS_DIR" ]]; then ok "projects directory: $PROJECTS_DIR"; else fail "projects directory missing: $PROJECTS_DIR"; fi

echo
echo "== SSH / IDE prerequisites =="
if command -v sshd >/dev/null 2>&1; then ok "sshd installed"; else fail "sshd missing"; fi
if systemctl is-active --quiet ssh 2>/dev/null; then ok "ssh service active"; else warn "ssh service not active or systemd unavailable"; fi
if command -v tar >/dev/null 2>&1; then ok "tar available"; else fail "tar missing"; fi
if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then ok "curl/wget available"; else fail "curl/wget missing"; fi
if grep -RqsE '^[[:space:]]*Subsystem[[:space:]]+sftp' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
  ok "SFTP subsystem configured (JetBrains prerequisite)"
else
  warn "SFTP subsystem line not found; verify sshd effective configuration"
fi

echo
echo "== Docker =="
if command -v docker >/dev/null 2>&1; then
  ok "docker installed: $(docker --version 2>/dev/null)"
  docker compose version 2>/dev/null || warn "docker compose plugin not available"
else
  warn "docker not installed"
fi

echo
echo "== OpenCode =="
if systemctl cat opencode >/dev/null 2>&1; then
  if systemctl is-active --quiet opencode; then ok "opencode service active"; else fail "opencode service installed but inactive"; fi
  WD="$(systemctl show opencode -p WorkingDirectory --value 2>/dev/null)"
  [[ "$WD" == "$PROJECTS_DIR" ]] && ok "WorkingDirectory=$WD" || warn "WorkingDirectory=$WD (expected $PROJECTS_DIR)"
else
  warn "opencode systemd service not installed"
fi

if command -v ss >/dev/null 2>&1; then
  if ss -lnt 2>/dev/null | grep -qE "127\.0\.0\.1:$OPENCODE_PORT\b"; then
    ok "OpenCode listens on localhost:$OPENCODE_PORT"
  elif ss -lnt 2>/dev/null | grep -qE ":$OPENCODE_PORT\b"; then
    warn "something listens on port $OPENCODE_PORT but not specifically localhost"
  else
    warn "nothing listening on port $OPENCODE_PORT"
  fi
fi

echo
echo "== Recommendation =="
echo "VS Code Remote SSH: remote desktop VS Code installation is not required."
echo "JetBrains Remote Development: keep SFTP enabled; local SSD and swap are recommended."
