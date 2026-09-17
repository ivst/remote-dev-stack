# Setup guide

This document gives the reproducible command sequence for a remote VPS and for a local Linux/WSL stand. Review `.env` before running anything.

## 1. Prepare configuration

```bash
cp .env.example .env
nano .env
```

Typical remote values:

```dotenv
DEV_USER=developer
PROJECTS_DIR=/home/developer/projects
OPENCODE_PORT=4096
OPENCODE_USERNAME=opencode
INSTALL_DOCKER=1
INSTALL_GH=1
INSTALL_OPENCODE=1
INSTALL_OPENCODE_SERVICE=1
CREATE_SWAP_GB=4
CONFIGURE_UFW=0
ALLOW_WEB=1
SSH_ALLOW_CIDRS=
```

Do not place `OPENCODE_SERVER_PASSWORD`, `GH_TOKEN`, GitHub personal access tokens or SSH private keys in the repository. `install-opencode-service.sh` generates an OpenCode password if none is provided and stores it in `/etc/remote-dev-stack/opencode.env` with mode `0600`.

## 2. Remote host: Ubuntu VPS

Connect as root or a sudo-capable provisioning user and run:

```bash
sudo ./scripts/bootstrap-host.sh remote
```

The script:

1. installs SSH/base utilities;
2. installs GitHub CLI (`gh`) when `INSTALL_GH=1`;
3. creates `DEV_USER` when needed;
4. creates `PROJECTS_DIR` with correct ownership;
5. installs Docker/Compose when enabled;
6. optionally creates swap;
7. installs OpenCode for `DEV_USER` when enabled;
8. leaves firewall policy unchanged unless `CONFIGURE_UFW=1`.

Install the OpenCode service:

```bash
sudo ./scripts/install-opencode-service.sh
sudo systemctl status opencode --no-pager
```

Verify the effective paths:

```bash
sudo systemctl show opencode -p WorkingDirectory -p ExecStart -p Environment
PID=$(systemctl show opencode -p MainPID --value)
sudo readlink -f /proc/$PID/cwd
```

Expected working directory:

```text
/home/developer/projects
```

The service listens only on:

```text
127.0.0.1:4096
```

Retrieve the generated OpenCode password only when needed:

```bash
sudo grep '^OPENCODE_SERVER_PASSWORD=' /etc/remote-dev-stack/opencode.env
```

### Optional UFW lockdown

Do this only after confirming that SSH key access works in a second terminal. Set, for example:

```dotenv
CONFIGURE_UFW=1
SSH_ALLOW_CIDRS=203.0.113.10/32,198.51.100.20/32
ALLOW_WEB=1
```

Then re-run:

```bash
sudo ./scripts/bootstrap-host.sh remote
```

The script refuses to enable restrictive UFW rules if `SSH_ALLOW_CIDRS` is empty.

## 3. GitHub SSH + GitHub CLI

Keep Git transport and GitHub API authentication separate:

```text
git clone / fetch / pull / push  -> SSH key
gh pr / issue / api / release   -> gh authentication
```

First verify that the development user's SSH key is accepted by GitHub:

```bash
sudo -u developer -H ssh -T git@github.com
```

A successful GitHub response looks like:

```text
Hi USER! You've successfully authenticated, but GitHub does not provide shell access.
```

GitHub intentionally returns no shell; that message confirms SSH authentication.

If `gh` was enabled in `.env`, `bootstrap-host.sh` installs it from the configured Ubuntu/Debian apt repositories. Verify:

```bash
gh --version
```

Then authenticate **as the development user**, not root:

```bash
sudo -u developer -H ./scripts/setup-github-cli.sh
```

The helper:

- checks GitHub SSH authentication;
- checks whether `gh` is already authenticated;
- starts browser/device login when authentication is missing;
- keeps `gh` Git protocol set to SSH;
- verifies the GitHub API account with `gh api user`.

Equivalent manual setup:

```bash
sudo -u developer -H gh auth login --hostname github.com --web --git-protocol ssh
sudo -u developer -H gh auth status --hostname github.com
sudo -u developer -H gh config set git_protocol ssh --host github.com
```

If interactive browser authentication is impossible, you may temporarily export a token in the shell and run the helper:

```bash
export GH_TOKEN='...'
./scripts/setup-github-cli.sh
unset GH_TOKEN
```

Do not put `GH_TOKEN` in `.env`. The helper can import it into `gh` authentication storage for the current user, but the token itself should not be committed or left in shell configuration unless that is an explicit administrative choice.

Useful verification commands:

```bash
gh auth status
gh api user --jq .login
gh repo view OWNER/PROJECT
gh pr list --repo OWNER/PROJECT
```

## 4. Clone projects

Work under one parent directory:

```bash
sudo -u developer -H bash
cd ~/projects
git clone git@github.com:OWNER/PROJECT.git
exit
```

Each client then opens the same checkout. Git remains the source of truth; there is no need to sync separate working copies between desktop and laptop.

## 5. Register projects in OpenCode

Normally OpenCode learns projects as they are opened. To register all Git repositories under `PROJECTS_DIR` in one pass:

```bash
sudo ./scripts/register-opencode-projects.sh
```

If OpenCode Web/PWA shows `No folders found`, enter the full path manually:

```text
/home/developer/projects/project-name
```

Do **not** change `HOME` to the projects directory. Keep:

```text
HOME=/home/developer
WorkingDirectory=/home/developer/projects
```

## 6. VS Code Remote SSH

On the remote host nothing else is normally required. VS Code installs its server automatically after the first SSH connection.

On the client install VS Code and the official **Remote - SSH** extension. You can generate an SSH config entry with:

```bash
./scripts/configure-client.sh
```

Or add one manually:

```sshconfig
Host dev-vps
    HostName dev.example.com
    User developer
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Verify:

```bash
ssh dev-vps
```

Then in VS Code:

```text
Remote-SSH: Connect to Host... → dev-vps
File → Open Folder... → /home/developer/projects/project-name
```

Do not install desktop VS Code on the VPS just for Remote SSH.

## 7. JetBrains Remote Development

The same host can be used with PhpStorm/IntelliJ Remote Development.

Requirements:

```bash
systemctl is-active ssh
command -v sftp-server || true
grep -R "^[[:space:]]*Subsystem[[:space:]]\+sftp" /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null || true
free -h
df -h /
```

From PhpStorm/IntelliJ/Gateway on the client:

```text
Remote Development → SSH Connection → New Connection
Host: dev.example.com
User: developer
Project: /home/developer/projects/project-name
```

JetBrains automatically deploys the remote backend. No full desktop IDE needs to be installed manually on the host.

For medium/large projects, use a host with fast CPU cores, local SSD and swap. If indexing drives sustained load close to the CPU limit, moving to a faster VM is preferable to adding RAM that remains unused.

## 8. Local Linux/WSL stand

To build the same directory layout locally:

```bash
sudo ./scripts/bootstrap-host.sh local
```

Local mode installs the same base development packages and optionally Docker/OpenCode/GitHub CLI, but does not enable UFW or start an OpenCode system service unless explicitly requested.

Authenticate `gh` as the local development user:

```bash
./scripts/setup-github-cli.sh
```

Then:

```bash
cd ~/projects
git clone git@github.com:OWNER/PROJECT.git
cd PROJECT
```

You can run OpenCode directly:

```bash
opencode
```

or explicitly start a local server:

```bash
OPENCODE_SERVER_PASSWORD='temporary-local-password' \
  opencode serve --hostname 127.0.0.1 --port 4096
```

## 9. FASTPANEL/nginx and a test domain

For applications running in Docker, prefer publishing the container only on localhost:

```yaml
services:
  app:
    ports:
      - "127.0.0.1:8081:80"
```

Then create a site in FASTPANEL, obtain a TLS certificate and reverse proxy the test hostname to:

```text
http://127.0.0.1:8081
```

For OpenCode, proxy to:

```text
http://127.0.0.1:4096
```

Keep the OpenCode vhost additionally protected with an IP allowlist and/or Cloudflare Access. Do not expose port 4096 directly in UFW.

### Cloudflare

For a test hostname:

1. Create a proxied DNS record (orange cloud) if you want Cloudflare proxying, or DNS-only if you only want Cloudflare as DNS provider.
2. When proxied, use **Full (strict)** TLS.
3. For private test environments, optionally create a Cloudflare Zero Trust Access application for the hostname.
4. Keep origin-side HTTPS and application/reverse-proxy controls; Cloudflare is not a replacement for origin security.

## 10. Health check

Run:

```bash
./scripts/check-stack.sh
```

Useful manual checks:

```bash
uptime
free -h
df -h /
docker version
docker compose version
gh auth status
ssh -T git@github.com
ss -lntup
systemctl status opencode --no-pager
```

For interval CPU measurements install `sysstat` and use:

```bash
pidstat -p PID 5 12
```

## 11. Backups and rollback

Use both layers:

- Git for project history.
- VPS/provider snapshots for the whole environment.

A useful snapshot point is immediately after SSH, Docker, GitHub CLI, firewall, OpenCode and the selected IDE remote workflow have been tested successfully.

Before major upgrades to OpenCode, Docker, FASTPANEL or the OS, take another snapshot.

## 12. Removal

Stop and disable OpenCode:

```bash
sudo systemctl disable --now opencode
sudo rm -f /etc/systemd/system/opencode.service
sudo systemctl daemon-reload
```

Remove its root-owned environment file:

```bash
sudo rm -rf /etc/remote-dev-stack
```

The scripts intentionally do not automatically remove Docker, GitHub CLI authentication, the development user, projects, firewall rules, or IDE caches because doing so can destroy unrelated work or credentials.
