# Setup guide

This stack targets Ubuntu/Debian hosts and **OpenCode V2**.

## 1. Configuration

```bash
cp .env.example .env
nano .env
```

Typical remote values:

```dotenv
DEV_USER=developer
PROJECTS_DIR=/home/developer/projects
INSTALL_DOCKER=1
INSTALL_GH=1
INSTALL_OPENCODE=1
INSTALL_OPENCODE_SERVICE=1
OPENCODE_MAJOR_VERSION=2
OPENCODE_INSTALL_URL=https://opencode.ai/v2/install
OPENCODE_PORT=4096
OPENCODE_USERNAME=opencode
CREATE_SWAP_GB=0
CONFIGURE_UFW=0
ALLOW_WEB=1
SSH_ALLOW_CIDRS=
```

Do not commit `OPENCODE_SERVER_PASSWORD`, provider API keys, GitHub tokens or SSH private keys. If the OpenCode server password is empty, `install-opencode-service.sh` generates one and stores it in:

```text
/etc/remote-dev-stack/opencode.env
```

with mode `0600`.

## 2. Fresh remote host

```bash
sudo ./scripts/bootstrap-host.sh remote
sudo -u developer -H ./scripts/setup-github-cli.sh
sudo ./scripts/install-opencode-service.sh
./scripts/check-stack.sh
```

The OpenCode service remains explicit and predictable:

```ini
User=developer
Environment=HOME=/home/developer
WorkingDirectory=/home/developer/projects
ExecStart=/home/developer/.opencode/bin/opencode serve --hostname 127.0.0.1 --port 4096
```

The server is not exposed directly to the Internet.

**Docker security note:** with `INSTALL_DOCKER=1`, the bootstrap script adds `DEV_USER` to the `docker` group. Members can control the Docker daemon and effectively gain root privileges on the host. Use this setup only for trusted development accounts; consider rootless Docker or host isolation for less-trusted users.

## 3. Existing V1 host → V2, no backup

For the current server, after pulling this repository:

```bash
cd /home/developer/projects/remote-dev-stack
git pull
sudo ./scripts/upgrade-opencode-v2.sh
./scripts/check-stack.sh
```

The migration script:

1. stops the existing `opencode.service`;
2. runs the official V2 installer as `DEV_USER`;
3. verifies that `opencode --version` starts with `2.`;
4. restarts the existing systemd service;
5. prints the resulting service status.

It deliberately creates **no backup**.

OpenCode V2 reads supported V1 config from the same locations and normalizes it in memory. V1 plugin implementations do not run in V2. Integrations using the V1 server API must be migrated.

See [OPENCODE_V2.md](OPENCODE_V2.md).

## 4. Verify V2

```bash
sudo -u developer -H /home/developer/.opencode/bin/opencode --version
sudo systemctl status opencode --no-pager
sudo systemctl show opencode -p WorkingDirectory -p ExecStart -p Environment
ss -lntp | grep ':4096'
```

Expected:

```text
OpenCode version: 2.x
WorkingDirectory=/home/developer/projects
listener: 127.0.0.1:4096
```

## 5. Connect the V2 terminal client to the dedicated server

Avoid putting the password in shell history:

```bash
read -rsp 'OpenCode password: ' OPENCODE_SERVER_PASSWORD
echo
export OPENCODE_SERVER_PASSWORD
```

Then open the project and connect:

```bash
cd /home/developer/projects/news-hub
opencode --server http://127.0.0.1:4096
```

When finished:

```bash
unset OPENCODE_SERVER_PASSWORD
```

V2 also has a built-in shared background service, but this remote stack intentionally keeps the always-on server under systemd using `opencode serve`.

## 6. Projects

Clone repositories under one parent directory:

```bash
cd /home/developer/projects
git clone git@github.com:OWNER/PROJECT.git
```

OpenCode V2 does not use the old V1 `/project/current` registration flow. Select/open the desired directory in the V2 client.

The compatibility helper:

```bash
./scripts/register-opencode-projects.sh
```

now only lists discovered Git repositories and prints V2 connection examples.

## 7. GitHub SSH + GitHub CLI

Verify GitHub SSH:

```bash
ssh -T git@github.com
```

Install/configure `gh`:

```bash
sudo apt install -y gh
./scripts/setup-github-cli.sh
```

Use SSH for Git transport and `gh auth` for PR/issues/API operations.

## 8. VS Code Remote SSH

On the client install VS Code and the official Remote - SSH extension.

Connect and open:

```text
/home/developer/projects/<project>
```

No desktop VS Code installation is required on the VPS.

## 9. JetBrains Remote Development

Use Gateway / Remote Development over SSH:

```text
Host: dev.example.com
User: developer
Project: /home/developer/projects/<project>
```

Keep SSH/SFTP enabled.

## 10. FASTPANEL/nginx

For Docker projects bind application ports to loopback:

```yaml
ports:
  - "127.0.0.1:8081:80"
```

Reverse proxy test domains through FASTPANEL/nginx.

For OpenCode:

```text
code.example.com -> http://127.0.0.1:4096
```

Keep Basic Auth plus an origin-side IP allowlist and/or Cloudflare Access.

See [FASTPANEL.md](FASTPANEL.md).

## 11. Firewall

Only enable restrictive UFW after SSH key access works from another terminal.

Example:

```dotenv
CONFIGURE_UFW=1
SSH_ALLOW_CIDRS=203.0.113.10/32,198.51.100.20/32
ALLOW_WEB=1
```

Then:

```bash
sudo ./scripts/bootstrap-host.sh remote
```

Port 4096 should not be opened publicly.

## 12. Health check

```bash
./scripts/check-stack.sh
```

Useful manual commands:

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

## 13. Removal

```bash
sudo systemctl disable --now opencode
sudo rm -f /etc/systemd/system/opencode.service
sudo systemctl daemon-reload
sudo rm -rf /etc/remote-dev-stack
```

This intentionally leaves Docker, GitHub CLI authentication, the development user, projects, firewall rules and IDE caches untouched.
