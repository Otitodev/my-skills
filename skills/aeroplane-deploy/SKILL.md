---
name: aeroplane-deploy
description: Deploy and manage apps on a self-hosted Aeroplane server (aeroplane.run), a Railway-style PaaS that builds from GitHub with Railpack or a Dockerfile and runs services in Docker behind Caddy. Use when the user wants to deploy, ship, host, or redeploy a project to Aeroplane or their own Aeroplane VPS, set up an Aeroplane server for the first time, connect GitHub for push deploys, set environment variables or custom domains, add a Postgres/Redis/MySQL/MongoDB database, read deployment or runtime logs, or fix a failed Aeroplane deployment. Not for Vercel, Railway, Fly, or other platforms.
---

# Deploy to Aeroplane

Aeroplane is a self-hosted deployment control plane. It connects to GitHub, builds a project with Railpack (or the project's own Dockerfile), runs it in Docker, and routes domains through Caddy. A dashboard and an HTTP API manage everything. Source: https://github.com/xt42io/aeroplane

Use this skill so the user never has to explain how Aeroplane works. Read what you need from `references/` instead of guessing. Paths like `references/...` and `scripts/...` are relative to **this skill's folder**, not the user's project, so use the full path when running the script from another directory.

## Vocabulary (it differs from the database)

- **Project** is a workspace for one app stack (web, workers, databases).
- **Service** is one deployable unit inside a project: a Git source, a Docker image, a database, a worker, or a static site.
- **Deployment** is one build-and-run of a service. Its status is `queued`, `building`, `running`, `superseded`, `aborted`, or `failed`.

## Rules

1. **Never print, log, or commit the API key.** Read it from the `AEROPLANE_API_KEY` environment variable only. Never write it into a repo file, and never pass it on a command line you echo.
2. **Some steps are browser-only.** Creating the owner account, GitHub App setup, system settings, DNS provider connections, and creating API keys cannot be done with an API key. Tell the user exactly what to click, then continue once they confirm.
3. **Confirm before anything destructive or public:** deleting a project or service, restoring a database backup, making a database public, or applying a system update. A first production deploy and a new custom domain also deserve a one-line confirmation.
4. **Do not SSH into the server or run the installer yourself** unless the user asks. Give them the command to run.
5. **Ground answers in this skill's references.** If something is not covered, say so and point at the Aeroplane docs or source. Do not invent endpoints or settings.

## Step 0: find out where the user is

Check `AEROPLANE_URL` and `AEROPLANE_API_KEY` (never show the key's value; test only that it is set). Then:

| Situation | Go to |
|---|---|
| No server yet, or no `AEROPLANE_URL` | `references/setup-server.md` |
| Server exists but no API key, or GitHub is not connected | `references/setup-server.md` (API key and GitHub sections) |
| Server and key are ready, user wants to ship a project | the workflow below |

Verify the connection with the helper (see "API helper"):

```sh
scripts/aeroplane-api.sh GET /api/health      # expects {"ok":true}
scripts/aeroplane-api.sh GET /api/projects    # proves the key works
```

## Deploy workflow

1. **Inspect the user's project.** Work out the stack, how it starts, which port it listens on, which env vars it needs (`.env.example`), and whether it is a web app, worker, static site, or needs a database. See `references/deploy-project.md`.
2. **Make it deployable.** The app must listen on `0.0.0.0` and the port from `$PORT`. Add a `Dockerfile` only if auto-detection would not work. Do not change the user's code beyond that without asking.
3. **Pick or create a project**, then create the **service** (GitHub repo, direct Git URL, or Docker image). Set `internalPort` to the port the app really listens on, because the API default is `8080`, not `3000`.
4. **Add environment variables** and any **database** service first, so the app can reference `${db-name.POSTGRES_URL}`. See `references/env-domains-tls.md` and `references/databases-logs-rollback.md`.
5. **Deploy**, then poll the deployment until it leaves `queued`/`building`. On `failed`, read the deployment logs before changing anything. See `references/troubleshooting.md`.
6. **Verify**: fetch the service overview for `primaryUrl`, request it, and check the runtime logs. Add a custom domain only if the user wants one.
7. **Make the next deploy easy.** With the GitHub App connected and the service on a GitHub repo and branch, every push to that branch deploys automatically. Record the project and service names in the user's project notes (`AGENTS.md` or `CLAUDE.md`) so later sessions can redeploy without rediscovery. Never record secrets there.

## API helper

`scripts/aeroplane-api.sh METHOD /api/path [json-body]` sends an authenticated request using `AEROPLANE_URL` and `AEROPLANE_API_KEY`, prints the JSON response, and exits non-zero on an HTTP error. It refuses plain `http://` URLs (other than localhost) so the key is not sent in clear text. Set `AEROPLANE_ALLOW_HTTP=1` only for a fresh install reached by `http://IP:4310` before a domain exists.

```sh
scripts/aeroplane-api.sh POST /api/projects '{"name":"Acme"}'
scripts/aeroplane-api.sh POST /api/services/SERVICE_ID/deployments
scripts/aeroplane-api.sh GET  /api/services/SERVICE_ID/deployments
```

The full endpoint list is in `references/api.md`.

## Things that surprise people

- A deploy always builds the **head of the configured branch**. There is no "deploy this commit" or "roll back" endpoint. To undo a bad release, `git revert` and push.
- A failed web rollout keeps the previous container serving traffic. A deploy that merely starts is not proof it works, so verify the URL.
- If a `Dockerfile` exists at the service root, Aeroplane uses it and **ignores** install, build, and start command overrides.
- Redeploying a database can briefly drop connections.
- Push deploys need the GitHub App webhook. A service created from a direct Git URL deploys manually only.
