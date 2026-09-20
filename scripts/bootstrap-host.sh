#!/usr/bin/env bash
set -Eeuo pipefail

MODE="${1:-remote}"
if [[ "$MODE" != "remote" && "$MODE" != "local" ]]; then
  echo "Usage: $0 [remote|local]" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$ROOT_DIR/.env"; set +a
fi

DEV_USER="${DEV_USER:-developer}"
PROJECTS_DIR="${PROJECTS_DIR:-/home/$DEV_USER/projects}"
INSTALL_DOCKER="${INSTALL_DOCKER:-1}"
INSTALL_GH="${INSTALL_GH:-1}"
INSTALL_OPENCODE="${INSTALL_OPENCODE:-1}"
INSTALL_OPENCODE_SERVICE="${INSTALL_OPENCODE_SERVICE:-1}"
OPENCODE_INSTALL_URL="${OPENCODE_INSTALL_URL:-https://opencode.ai/v2/install}"
OPENCODE_MAJOR_VERSION="${OPENCODE_MAJOR_VERSION:-2}"
CREATE_SWAP_GB="${CREATE_SWAP_GB:-0}"
CONFIGURE_UFW="${CONFIGURE_UFW:-0}"
ALLOW_WEB="${ALLOW_WEB:-1}"
SSH_ALLOW_CIDRS="${SSH_ALLOW_CIDRS:-}"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo/root: sudo $0 $MODE" >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This bootstrap currently targets Ubuntu/Debian hosts with apt." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y   ca-certificates curl wget git openssh-server bash tar unzip zip jq rsync tmux htop   gnupg lsb-release build-essential ufw openssl

if [[ "$INSTALL_GH" == "1" ]]; then
  if apt-cache show gh >/dev/null 2>&1; then
    apt-get install -y gh
  else
    echo "WARN: GitHub CLI package 'gh' is not available from the configured apt repositories." >&2
    echo "      Install it from the official GitHub CLI repository, then run scripts/setup-github-cli.sh." >&2
  fi
fi

systemctl enable --now ssh

if ! id "$DEV_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$DEV_USER"
  usermod -aG sudo "$DEV_USER"
  echo "Created user: $DEV_USER"
fi

DEV_HOME="$(getent passwd "$DEV_USER" | cut -d: -f6)"
if [[ -z "$DEV_HOME" || ! -d "$DEV_HOME" ]]; then
  echo "Could not determine home directory for $DEV_USER" >&2
  exit 1
fi

mkdir -p "$PROJECTS_DIR"
chown -R "$DEV_USER:$DEV_USER" "$PROJECTS_DIR"

if [[ "$INSTALL_DOCKER" == "1" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    apt-get install -y docker.io
  fi
  if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
    apt-get install -y docker-compose-v2
  elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
    apt-get install -y docker-compose-plugin
  else
    apt-get install -y docker-compose || true
  fi
  systemctl enable --now docker
  usermod -aG docker "$DEV_USER"
fi

if [[ "$CREATE_SWAP_GB" =~ ^[0-9]+$ ]] && (( CREATE_SWAP_GB > 0 )); then
  if ! swapon --show=NAME --noheadings | grep -q .; then
    fallocate -l "${CREATE_SWAP_GB}G" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
    swapon /swapfile
    grep -qE '^/swapfile\s' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "Created ${CREATE_SWAP_GB}G swapfile."
  else
    echo "Swap already exists; leaving it unchanged."
  fi
fi

if [[ "$INSTALL_OPENCODE" == "1" ]]; then
  CURRENT_VERSION="$(sudo -u "$DEV_USER" -H bash -lc '
    if command -v opencode >/dev/null 2>&1; then opencode --version 2>/dev/null || true;
    elif [[ -x "$HOME/.opencode/bin/opencode" ]]; then "$HOME/.opencode/bin/opencode" --version 2>/dev/null || true;
    fi
  ')"

  if [[ "$CURRENT_VERSION" == "$OPENCODE_MAJOR_VERSION".* ]]; then
    echo "OpenCode V$OPENCODE_MAJOR_VERSION already installed: $CURRENT_VERSION"
  else
    if [[ -n "$CURRENT_VERSION" ]]; then
      echo "Replacing OpenCode $CURRENT_VERSION with V$OPENCODE_MAJOR_VERSION."
      echo "No backup is created by this script."
    else
      echo "Installing OpenCode V$OPENCODE_MAJOR_VERSION for $DEV_USER."
    fi
    sudo -u "$DEV_USER" -H env OPENCODE_INSTALL_URL="$OPENCODE_INSTALL_URL" bash -lc       'curl -fsSL "$OPENCODE_INSTALL_URL" | bash'
  fi
fi

if [[ "$MODE" == "remote" && "$CONFIGURE_UFW" == "1" ]]; then
  if [[ -z "$SSH_ALLOW_CIDRS" ]]; then
    echo "Refusing to enable restrictive UFW: SSH_ALLOW_CIDRS is empty." >&2
    exit 1
  fi

  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing

  IFS=',' read -r -a CIDRS <<< "$SSH_ALLOW_CIDRS"
  for cidr in "${CIDRS[@]}"; do
    cidr="${cidr//[[:space:]]/}"
    [[ -z "$cidr" ]] && continue
    ufw allow from "$cidr" to any port 22 proto tcp
  done

  if [[ "$ALLOW_WEB" == "1" ]]; then
    ufw allow 80/tcp
    ufw allow 443/tcp
  fi

  ufw --force enable
  ufw status verbose
fi

if [[ "$MODE" == "remote" && "$INSTALL_OPENCODE_SERVICE" == "1" ]]; then
  echo
  echo "Base host is ready. Next run:"
  echo "  sudo $ROOT_DIR/scripts/install-opencode-service.sh"
fi

if [[ "$INSTALL_GH" == "1" && -x "$(command -v gh 2>/dev/null || true)" ]]; then
  echo "GitHub CLI is installed. Authenticate it as $DEV_USER with:"
  echo "  sudo -u $DEV_USER -H $ROOT_DIR/scripts/setup-github-cli.sh"
fi

echo
echo "Host bootstrap complete."
echo "User:        $DEV_USER"
echo "Home:        $DEV_HOME"
echo "Projects:    $PROJECTS_DIR"
echo "Mode:        $MODE"
