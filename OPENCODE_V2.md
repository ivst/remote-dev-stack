# OpenCode V2

This repository targets OpenCode V2.

Official V2 installer:

```bash
curl -fsSL https://opencode.ai/v2/install | bash
```

## Direct V1 → V2 migration used by this stack

For an already configured remote host:

```bash
cd /home/developer/projects/remote-dev-stack
git pull
sudo ./scripts/upgrade-opencode-v2.sh
```

This migration deliberately creates **no backup**.

The official V2 installer replaces the V1 binary. V1 and V2 use the same main configuration locations, including:

```text
~/.config/opencode/opencode.json(c)
<project>/opencode.json(c)
<project>/.opencode/opencode.json(c)
```

Supported V1 config is normalized in memory by V2, so a complete config rewrite is not required before first start.

## Important breaking changes

OpenCode V2 intentionally changes:

1. plugin API;
2. server API/client contracts;
3. terminal client configuration.

V1 plugin implementations do not run in V2 and must be ported.

Integrations calling V1 HTTP endpoints must be migrated to the V2 API/client. In particular, this stack no longer calls the V1 `/project/current` endpoint.

The terminal client uses global:

```text
~/.config/opencode/cli.json
```

V2 can migrate supported global V1 terminal preferences on first terminal client startup.

## Dedicated remote server

For an always-on remote host, this stack intentionally keeps `opencode serve` under systemd rather than relying on the per-user background service:

```ini
[Service]
User=developer
Environment=HOME=/home/developer
WorkingDirectory=/home/developer/projects
ExecStart=/home/developer/.opencode/bin/opencode serve --hostname 127.0.0.1 --port 4096
```

Authentication is supplied through:

```text
/etc/remote-dev-stack/opencode.env
```

with:

```dotenv
OPENCODE_SERVER_USERNAME=opencode
OPENCODE_SERVER_PASSWORD=...
```

Keep port 4096 bound to localhost.

## Terminal client

Load the password:

```bash
read -rsp 'OpenCode password: ' OPENCODE_SERVER_PASSWORD
echo
export OPENCODE_SERVER_PASSWORD
```

Open a project and connect:

```bash
cd /home/developer/projects/news-hub
opencode --server http://127.0.0.1:4096
```

Then:

```bash
unset OPENCODE_SERVER_PASSWORD
```

## Web/mobile

The same dedicated server can be reverse proxied through FASTPANEL/nginx for browser/mobile clients:

```text
https://code.example.com
        -> nginx
        -> http://127.0.0.1:4096
```

Keep Basic Auth enabled and add an nginx IP allowlist and/or Cloudflare Access.

OpenCode V2 exposes a revised server API intended for current V2 clients. A native mobile client that explicitly supports the V2 API is preferable to a WebView wrapper when the mobile Web UI has frontend-specific problems.

## Verification

```bash
/home/developer/.opencode/bin/opencode --version
sudo systemctl status opencode --no-pager
ss -lntp | grep ':4096'
```

Run the repository health check:

```bash
./scripts/check-stack.sh
```

## V2 diagnostics

Useful V2 commands:

```bash
opencode debug paths
opencode debug config
opencode auth list
opencode models
```

For the built-in shared service, V2 also provides:

```bash
opencode service status
opencode pair
```

This stack does not use the built-in shared service for the remote VPS; it uses the explicit systemd-managed `opencode serve` process.

## Upstream references

- https://opencode.ai/v2/docs
- https://opencode.ai/v2/docs/migrate-v1
- https://opencode.ai/v2/docs/cli/web
- https://opencode.ai/v2/docs/cli
