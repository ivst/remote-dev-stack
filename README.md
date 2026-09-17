# remote-dev-stack

Reusable remote development stack for keeping the working copy of projects on a Linux host while using VS Code Remote SSH, JetBrains Remote Development, OpenCode Web/TUI, Docker, GitHub CLI and an optional reverse proxy (FASTPANEL/nginx + Cloudflare).

## Goal

The host is the single active development workspace:

```text
Desktop / Laptop / Phone
        |
        +-- VS Code Remote SSH
        +-- JetBrains Gateway / Remote Development
        +-- OpenCode Web / PWA / TUI
        |
        v
Remote or local Linux dev host
        |
        +-- ~/projects/*          source checkouts
        +-- Docker / Compose     application runtime
        +-- Git over SSH         clone/fetch/pull/push
        +-- GitHub CLI (gh)      PR/issues/API operations
        +-- OpenCode serve       localhost only
        +-- nginx / FASTPANEL    optional HTTPS reverse proxy
```

The repository contains no credentials. Secrets and host-specific values belong in `.env` or root-owned environment files and must not be committed.

## Supported host model

The scripts target recent Ubuntu LTS releases on x86_64. They are intentionally conservative and should also work on many Debian-like systems, but Ubuntu is the tested design target.

### VS Code Remote SSH

No desktop VS Code installation is required on the Linux host. The local VS Code Remote - SSH extension connects over SSH and installs VS Code Server automatically. The remote host needs a working SSH server, Bash, `tar`, and `curl` or `wget`.

### JetBrains Remote Development

JetBrains Gateway / Remote Development deploys the backend over SSH/SFTP. The host needs a compatible SSH server and SFTP subsystem. JetBrains documents 2+ CPU cores, 4 GB+ RAM and 5 GB+ free disk as a baseline, and recommends local SSD and swap. For real PhpStorm/IntelliJ projects, especially with indexing and containers running at the same time, considerably more CPU/RAM is practical; fast CPU cores matter more than a large amount of idle RAM.

### GitHub CLI

The stack keeps two independent GitHub authentication paths:

```text
git clone / fetch / pull / push  -> SSH key (~/.ssh/...)
gh pr / issue / api / release   -> GitHub CLI authentication
```

`bootstrap-host.sh` installs `gh` by default when `INSTALL_GH=1`. Authenticate it as the development user:

```bash
sudo -u developer -H ./scripts/setup-github-cli.sh
```

The helper verifies the existing GitHub SSH key, starts `gh auth login` when needed, and keeps `gh` repository transport set to SSH. It does not store a GitHub token in this repository.

### OpenCode

OpenCode runs as the development user and, on a remote host, can be kept under systemd:

```text
HOME=/home/developer
WorkingDirectory=/home/developer/projects
opencode serve --hostname 127.0.0.1 --port 4096
```

Keep the OpenCode port bound to localhost. Publish it only through a reverse proxy with HTTPS and an additional access control layer (IP allowlist and/or Cloudflare Access). OpenCode's own Basic Auth is enabled through `OPENCODE_SERVER_PASSWORD`.

OpenCode Web's project picker may show `No folders found` on some versions even when the backend can read the projects directory. A reliable workaround is to enter the full path manually, for example:

```text
/home/developer/projects/news-hub
```

## Repository layout

```text
README.md
SETUP.md
FASTPANEL.md
.env.example
.gitignore
scripts/
  bootstrap-host.sh
  install-opencode-service.sh
  setup-github-cli.sh
  configure-client.sh
  check-stack.sh
  register-opencode-projects.sh
```

## Quick start

On a fresh remote Ubuntu host:

```bash
git clone <this-repository-url>
cd remote-dev-stack
cp .env.example .env
nano .env
sudo ./scripts/bootstrap-host.sh remote
sudo -u developer -H ./scripts/setup-github-cli.sh
sudo ./scripts/install-opencode-service.sh
./scripts/check-stack.sh
```

On a local Ubuntu/WSL development host:

```bash
cp .env.example .env
nano .env
sudo ./scripts/bootstrap-host.sh local
./scripts/setup-github-cli.sh
./scripts/check-stack.sh
```

On a client machine with OpenSSH available:

```bash
./scripts/configure-client.sh
```

Then use either:

- VS Code: **Remote-SSH: Connect to Host...** and open the project directory.
- JetBrains: **Remote Development / Gateway → SSH Connection** and select the project directory.
- OpenCode: browser/PWA through the protected reverse proxy, or TUI over SSH.
- GitHub CLI: `gh pr`, `gh issue`, `gh api`, releases and other GitHub API-backed actions directly from the development host.

See [SETUP.md](SETUP.md) for the full installation sequence and [FASTPANEL.md](FASTPANEL.md) for publishing test projects through localhost ports, FASTPANEL/nginx and optional Cloudflare Access.

## Security defaults

- SSH key authentication is preferred.
- Git repository traffic stays on SSH; `gh` uses its own GitHub API authentication.
- GitHub tokens are not stored in `.env` or committed to the repository.
- The bootstrap script does **not** enable restrictive UFW rules unless explicitly requested.
- OpenCode listens on `127.0.0.1` only.
- OpenCode credentials are stored outside the repository in a root-owned file.
- Docker application ports should normally bind to `127.0.0.1`, for example `127.0.0.1:8081:80`, and be exposed through nginx/FASTPANEL.
- Never commit `.env`, API keys, SSH private keys, Basic Auth passwords, GitHub tokens or Cloudflare tokens.

## Source references

Current vendor documentation used when preparing this stack:

- VS Code Remote SSH: https://code.visualstudio.com/docs/remote/ssh
- JetBrains Remote Development prerequisites: https://www.jetbrains.com/help/idea/prerequisites.html
- JetBrains Gateway: https://www.jetbrains.com/help/phpstorm/remote-development-a.html
- GitHub CLI authentication: https://cli.github.com/manual/gh_auth_login
- OpenCode server: https://dev.opencode.ai/docs/server/
- OpenCode Web/server mode: https://opencode.ai/v2/docs/cli/web
