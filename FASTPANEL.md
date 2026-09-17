# FASTPANEL / nginx / Cloudflare

This document describes a simple way to publish development and test projects from the remote dev host without exposing application ports directly to the Internet.

Recommended topology:

```text
Browser
  |
  v
Cloudflare (optional proxy / Access)
  |
  v
HTTPS :443
FASTPANEL / nginx
  |
  v
127.0.0.1:<project-port>
  |
  v
Docker / application runtime
```

The important rule is that application containers and development services should normally listen on loopback only. Public traffic should enter through nginx/FASTPANEL on ports 80/443.

## 1. Example: publish a Docker project

Assume the project is:

```text
/home/developer/projects/news-hub
```

and the desired test hostname is:

```text
dev-news.example.com
```

Expose the application's HTTP port only on localhost. In `compose.yml` / `docker-compose.yml`:

```yaml
services:
  app:
    ports:
      - "127.0.0.1:8081:80"
```

Use any free local port instead of `8081`.

Start the project:

```bash
cd /home/developer/projects/news-hub
docker compose up -d
```

Check it locally on the host:

```bash
curl -I http://127.0.0.1:8081
```

Do not add a public UFW rule for `8081`.

## 2. Create the site in FASTPANEL

In FASTPANEL create a site for the test hostname, for example:

```text
dev-news.example.com
```

The exact menu labels can differ by FASTPANEL version, but the intended configuration is:

1. Create the site/domain.
2. Enable HTTPS and issue a certificate.
3. Configure nginx to proxy requests to:

```text
http://127.0.0.1:8081
```

A minimal nginx proxy location looks like:

```nginx
location / {
    proxy_pass http://127.0.0.1:8081;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

The `Upgrade` headers are useful for applications that use WebSockets. They are usually harmless for ordinary HTTP applications.

Before editing FASTPANEL-generated nginx files directly, prefer the panel's supported custom include mechanism. Manual edits to generated vhost files can be overwritten by the panel.

Validate nginx after changing configuration:

```bash
sudo nginx -t
```

Then reload:

```bash
sudo systemctl reload nginx
```

## 3. Cloudflare DNS

If the zone is managed by Cloudflare, create an `A` or `AAAA` record for the test hostname pointing to the dev VPS.

Typical example:

```text
Type: A
Name: dev-news
Content: <VPS public IPv4>
Proxy status: Proxied
```

With the orange-cloud proxy enabled, clients connect to Cloudflare first and Cloudflare connects to nginx/FASTPANEL.

For normal HTTPS origin setups, use Cloudflare SSL/TLS mode:

```text
Full (strict)
```

and keep a valid certificate on the origin server.

## 4. Protect a test site with Cloudflare Access

For private test environments it is often more convenient to protect the hostname at Cloudflare instead of building temporary authentication into the application.

Typical flow:

```text
Browser
  |
  v
Cloudflare Access login
  |
  v
Cloudflare proxy
  |
  v
FASTPANEL / nginx
  |
  v
127.0.0.1:8081
```

In Cloudflare Zero Trust:

1. Open **Access → Applications**.
2. Add a **Self-hosted** application.
3. Set the hostname, for example `dev-news.example.com`.
4. Add an **Allow** policy for the required email addresses, identity provider groups, or other supported identities.
5. Keep a final deny-by-default behavior for everyone else.

This is useful when the site must be opened from changing IP addresses, phones, laptops or external testers.

## 5. IP allowlist instead of Cloudflare Access

For highly restricted admin tools, an nginx IP allowlist is simpler and has fewer moving parts.

Example:

```nginx
allow 203.0.113.10;
allow 198.51.100.25;
deny all;
```

This works well for stable VPN exit IPs.

Do not automatically copy the same allowlist to ordinary test applications if they need to be opened by testers, clients, mobile networks or changing VPN exits.

## 6. OpenCode Web example

OpenCode should continue listening only on loopback:

```text
127.0.0.1:4096
```

The systemd service should contain the equivalent of:

```ini
[Service]
User=developer
Environment=HOME=/home/developer
WorkingDirectory=/home/developer/projects
ExecStart=/home/developer/.opencode/bin/opencode serve --hostname 127.0.0.1 --port 4096
```

nginx / FASTPANEL can proxy a hostname such as:

```text
code.example.com -> http://127.0.0.1:4096
```

For OpenCode, keep at least two layers of protection where practical:

```text
HTTPS
+ nginx IP allowlist or Cloudflare Access
+ OpenCode Basic Auth
```

Do not expose port `4096` publicly.

## 7. Laravel without Docker

A Laravel project can also be served directly by nginx + PHP-FPM. The document root must point to Laravel's `public` directory, for example:

```text
/home/developer/projects/news-hub/public
```

This can be efficient, but on a shared development host it introduces more coupling between project files, FASTPANEL users, PHP-FPM pools, ownership and permissions.

For a generic reusable remote development server, Docker + localhost reverse proxy is usually easier to isolate and reproduce.

## 8. Multiple projects

Assign one local port and one hostname to each project:

```text
127.0.0.1:8081 -> dev-news.example.com
127.0.0.1:8082 -> dev-site.example.com
127.0.0.1:8083 -> dev-mobile-api.example.com
```

Check used ports:

```bash
sudo ss -lntp
```

Or only loopback listeners:

```bash
sudo ss -lntp | grep '127.0.0.1'
```

A simple convention helps avoid collisions, for example allocating application test ports from `8081-8099`.

## 9. Verify that a project is not exposed directly

Check the listener:

```bash
sudo ss -lntp | grep ':8081'
```

Good:

```text
127.0.0.1:8081
```

Avoid:

```text
0.0.0.0:8081
[::]:8081
```

Also verify UFW:

```bash
sudo ufw status numbered
```

Normally only nginx-facing ports such as `80/tcp` and `443/tcp` need to be public. SSH should preferably be restricted to trusted IP addresses or a VPN.

## 10. Quick checklist for a new test project

```text
[ ] Project cloned into /home/developer/projects/<project>
[ ] Application starts successfully
[ ] Container/service binds to 127.0.0.1:<port>
[ ] curl http://127.0.0.1:<port> works on the host
[ ] FASTPANEL site created
[ ] nginx proxies hostname to localhost port
[ ] nginx -t passes
[ ] HTTPS certificate active
[ ] DNS record created
[ ] Cloudflare proxy enabled if desired
[ ] Cloudflare Access or nginx allowlist enabled if private
[ ] Direct application port is not publicly reachable
```

## 11. Recommended pattern for this stack

For remote development and testing, prefer:

```text
Git checkout
  -> Docker Compose
  -> 127.0.0.1:<port>
  -> FASTPANEL/nginx
  -> HTTPS hostname
  -> optional Cloudflare proxy / Access
```

This keeps project runtime isolated from FASTPANEL while retaining FASTPANEL for certificates, vhosts and reverse proxy configuration.
