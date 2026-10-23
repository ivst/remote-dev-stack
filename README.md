# remote-dev-stack

Reusable remote development stack for keeping project working copies on a Linux host while using VS Code Remote SSH, JetBrains Remote Development, OpenCode V2, Docker, GitHub CLI and an optional FASTPANEL/nginx reverse proxy.

## Architecture

```text
Desktop / Laptop / Phone
        |
        +-- VS Code Remote SSH
        +-- JetBrains Gateway / Remote Development
        +-- OpenCode V2 client / mobile client
        +-- OpenCode Web
        |
        v
Remote or local Linux dev host
        |
        +-- ~/projects/*          source checkouts
        +-- Docker / Compose     application runtime
        +-- Git over SSH         clone/fetch/pull/push
        +-- GitHub CLI (gh)      PR/issues/API operations
        +-- OpenCode V2 serve    localhost only
        +-- nginx / FASTPANEL    optional HTTPS reverse proxy
```

Git remains the source of truth/history. The Linux host is the active working state.

## OpenCode V2

This stack targets **OpenCode V2**.

Official V2 installer:

```bash
curl -fsSL https://opencode.ai/v2/install | bash
```

The remote host keeps a dedicated foreground server under systemd:

```text
HOME=/home/developer
WorkingDirectory=/home/developer/projects
opencode serve --hostname 127.0.0.1 --port 4096
```

V2 clients can connect to that server instead of launching another private backend:

```bash
export OPENCODE_SERVER_PASSWORD='...'
cd /home/developer/projects/news-hub
opencode --server http://127.0.0.1:4096
```

The V2 server API is intentionally different from V1. Do not use old V1 automation that calls endpoints such as `/project/current`.

See [OPENCODE_V2.md](OPENCODE_V2.md) for migration and client notes.

## Repository layout

```text
README.md
SETUP.md
FASTPANEL.md
OPENCODE_V2.md
.env.example
.gitignore
scripts/
  bootstrap-host.sh
  upgrade-opencode-v2.sh
  install-opencode-service.sh
  setup-github-cli.sh
  configure-client.sh
  check-stack.sh
  register-opencode-projects.sh
```

## Quick start: fresh remote host

```bash
git clone git@github.com:ivst/remote-dev-stack.git
cd remote-dev-stack

cp .env.example .env
nano .env

sudo ./scripts/bootstrap-host.sh remote
sudo -u developer -H ./scripts/setup-github-cli.sh
sudo ./scripts/install-opencode-service.sh
./scripts/check-stack.sh
```

## Upgrade an existing V1 host to V2

For the current stack:

```bash
git pull
sudo ./scripts/upgrade-opencode-v2.sh
./scripts/check-stack.sh
```

The migration script intentionally creates **no backup**. It stops the existing systemd service, installs V2 using the official V2 installer, verifies major version 2, and restarts the same localhost-only service.

V1 and V2 use the same main configuration locations. Supported V1 configuration is normalized by V2 in memory, but V1 plugins and integrations using the old server API require migration.

## VS Code Remote SSH

Install VS Code and the official Remote - SSH extension on the client. Do not install desktop VS Code on the VPS just for Remote SSH.

Open:

```text
/home/developer/projects/<project>
```

## JetBrains Remote Development

JetBrains Gateway / Remote Development uses SSH/SFTP and deploys its backend to the server automatically.

For larger projects, fast CPU cores and disk latency matter more than simply adding idle RAM. Keep SFTP enabled.

## GitHub

Git transport remains SSH:

```bash
ssh -T git@github.com
```

GitHub CLI is installed separately for PR/issues/API operations:

```bash
sudo apt install -y gh
./scripts/setup-github-cli.sh
```

Do not put GitHub tokens in the repository.

## Security defaults

- SSH keys preferred.
- OpenCode listens only on `127.0.0.1`.
- OpenCode Basic Auth is stored outside Git in `/etc/remote-dev-stack/opencode.env`.
- Docker application ports should normally bind to `127.0.0.1:<port>`.
- Publish services through nginx/FASTPANEL.
- Keep OpenCode Web additionally behind an IP allowlist and/or Cloudflare Access.
- Never commit `.env`, provider API keys, SSH private keys, OpenCode passwords, GitHub tokens or Cloudflare tokens.
- **Docker group privilege:** when `INSTALL_DOCKER=1`, `bootstrap-host.sh` adds `DEV_USER` to the `docker` group. Access to the Docker daemon is effectively root-equivalent on the host. Only grant membership to trusted users; for multi-user or untrusted environments consider rootless Docker or stronger host isolation.

### Check for secrets before publishing

`.gitignore` reduces accidental commits, but it does not protect secrets that were already tracked or committed. Review staged changes and scan both Git history and the working tree with [Gitleaks](https://github.com/gitleaks/gitleaks) (v8.19+):

```bash
git diff --cached --check
gitleaks git --redact --log-opts="--all" .
gitleaks dir --redact .
```

If you find a real credential in Git history, revoke/rotate it before publication. Removing it from the latest commit or adding a `.gitignore` rule is not sufficient.

## Documentation

- [SETUP.md](SETUP.md) — full host/client setup.
- [OPENCODE_V2.md](OPENCODE_V2.md) — V1 → V2 migration and V2 usage.
- [FASTPANEL.md](FASTPANEL.md) — publishing test projects and OpenCode through nginx/FASTPANEL.

## Upstream documentation

- OpenCode V2: https://opencode.ai/v2/docs
- V1 → V2 migration: https://opencode.ai/v2/docs/migrate-v1
- OpenCode V2 Web/server: https://opencode.ai/v2/docs/cli/web
- VS Code Remote SSH: https://code.visualstudio.com/docs/remote/ssh
- JetBrains Remote Development: https://www.jetbrains.com/help/idea/remote-development-overview.html
- GitHub CLI authentication: https://cli.github.com/manual/gh_auth_login
