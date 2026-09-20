#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run this script as the development user, not as root." >&2
  echo "Example: sudo -u developer -H $0" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is not installed." >&2
  echo "On Ubuntu: sudo apt update && sudo apt install -y gh" >&2
  exit 1
fi

echo "GitHub CLI: $(gh --version | head -n1)"

echo
echo "== Git SSH authentication =="
SSH_OUTPUT="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
echo "$SSH_OUTPUT"
if grep -qi "successfully authenticated" <<< "$SSH_OUTPUT"; then
  echo "OK: GitHub SSH authentication works."
else
  echo "WARN: GitHub SSH authentication was not confirmed."
  echo "      Git clone/pull/push over SSH may require an SSH key to be added to GitHub."
fi

echo
echo "== GitHub CLI authentication =="
if gh auth status --hostname github.com >/dev/null 2>&1; then
  echo "GitHub CLI is already authenticated."
else
  if [[ -n "${GH_TOKEN:-}" ]]; then
    echo "GH_TOKEN is present; importing it into gh authentication storage."
    printf '%s' "$GH_TOKEN" | gh auth login --hostname github.com --with-token
  else
    echo "Starting GitHub browser/device authentication."
    echo "No token will be written to this repository."
    gh auth login --hostname github.com --web --git-protocol ssh
  fi
fi

# Keep repository operations on the existing SSH path even though gh uses API auth
# for PRs, issues, releases and other GitHub API actions.
gh config set git_protocol ssh --host github.com

echo
echo "== Verification =="
gh auth status --hostname github.com
LOGIN="$(gh api user --jq .login 2>/dev/null || true)"
if [[ -n "$LOGIN" ]]; then
  echo "GitHub API user: $LOGIN"
fi

echo "Git protocol for gh: $(gh config get git_protocol --host github.com 2>/dev/null || echo unknown)"

echo
echo "GitHub CLI setup complete."
echo "Git repository transport: SSH key"
echo "GitHub API / PR / issue operations: gh authentication"
