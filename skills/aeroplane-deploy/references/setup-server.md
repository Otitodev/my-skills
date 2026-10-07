# First-time server setup

Walk the user through these in order. Steps marked **[browser]** cannot be done with an API key.

## 1. Requirements

- A server the user controls, running **Ubuntu or Debian**, with shell access.
- Public ports **80** and **443** free for Caddy. Port **4310** is the control plane's fallback port.
- Docker support, enough disk for builds, images, database volumes, and backups.
- DNS access for any hostname they want to point at the server.

## 2. Install (the user runs this on the server)

```sh
curl -fsSL https://get.aeroplane.run | sh
```

The installer creates `/opt/aeroplane`, clones the source to `/opt/aeroplane/source`, writes a production `.env`, builds the control plane, and starts three things: the `aeroplane` systemd service, `deploy-buildkit` on `127.0.0.1:1234`, and `deploy-caddy` on ports 80 and 443. It prints a URL when it finishes.

Optional overrides, set before `sh`:

```sh
curl -fsSL https://get.aeroplane.run | \
  AEROPLANE_PUBLIC_URL=https://pilot.example.com \
  AEROPLANE_REPO_BRANCH=main \
  AEROPLANE_PORT=4310 \
  sh
```

`AEROPLANE_HOME` (default `/opt/aeroplane`), `AEROPLANE_REPO_URL`, `AEROPLANE_REPO_BRANCH` (default `main`), `AEROPLANE_PUBLIC_URL`, and `AEROPLANE_PORT` (default `4310`).

If UFW is enabled:

```sh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 4310/tcp
```

Check on it:

```sh
sudo journalctl -u aeroplane -f
cd /opt/aeroplane && sudo docker compose logs -f caddy buildkit
```

## 3. Onboarding **[browser]**

Open the printed URL (`http://SERVER_IP:4310` works as a fallback) and complete onboarding:

1. **Create the owner account.** It controls system settings, GitHub details, and maintenance. Keep it separate from app users.
2. **Dashboard domain (optional but recommended).** Pick something like `pilot.example.com` and add DNS records:
   ```txt
   A     pilot.example.com     SERVER_IPV4
   AAAA  pilot.example.com     SERVER_IPV6
   ```
3. **Wildcard root domain (optional).** Lets Aeroplane generate a hostname for every service, for example `api.pilot.example.com`:
   ```txt
   A     *.pilot.example.com   SERVER_IPV4
   AAAA  *.pilot.example.com   SERVER_IPV6
   ```
   Enter it as `*.pilot.example.com`.
4. **Connect GitHub** (next section).
5. **Backups (optional).** Off by default. Connect a Cloudflare R2 bucket if they want off-server backups.

If they are moving from another Aeroplane server, onboarding can import a `.aeroplane` migration bundle (needs the source server's passphrase).

## 4. Connect GitHub **[browser]**

A **GitHub App** is the recommended path. It enables repository browsing and push-triggered deploys.

- Repository permissions: **Contents: Read** and **Metadata: Read**.
- Subscribe to the **Push** event.
- Webhook URL: `https://YOUR_PUBLIC_HOST/api/github/app/webhook`
- Set a webhook secret, and enter the app details during onboarding or later in System Settings. Without a webhook secret the webhook endpoint returns 503.

Fallback: a `GITHUB_ACCESS_TOKEN` in the server environment. It works for cloning but is worse for repository selection and has no push webhooks.

Private SSH Git URLs need SSH credentials on the host itself.

## 5. Create an API key **[browser]**

Open **System Settings -> API Access -> Create API key**.

- **Access:** `Read and write` to deploy. `Read` can only inspect.
- **Projects:** all projects, or specific ones. A key scoped to specific projects **cannot create new projects**, so use an all-projects write key for first-time setup.
- **Expiration:** 7, 30, 90 days, or never.

The full key is shown **once**. Have the user copy it straight into an environment variable, not into a file in a repo.

## 6. Store the connection details outside the repo

```sh
# bash/zsh, add to ~/.bashrc or ~/.zshrc
export AEROPLANE_URL="https://pilot.example.com"
export AEROPLANE_API_KEY="ap_..."
```

```powershell
# PowerShell, persists for the user account (restart the terminal afterwards)
[Environment]::SetEnvironmentVariable("AEROPLANE_URL", "https://pilot.example.com", "User")
[Environment]::SetEnvironmentVariable("AEROPLANE_API_KEY", "ap_...", "User")
```

Remind the user that coding sessions started before this will not see the new variables.

Then verify:

```sh
scripts/aeroplane-api.sh GET /api/health
scripts/aeroplane-api.sh GET /api/projects
```

## 7. Updates and migration (mention only if asked)

System updates, maintenance, migration export, and DNS provider connections (Cloudflare, Namecheap, Spaceship) live in **System Settings** and are browser-only. Updates refuse to apply if the install checkout is dirty or has diverged.
