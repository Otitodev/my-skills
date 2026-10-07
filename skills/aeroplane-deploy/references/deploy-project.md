# Deploying a project

## 1. Choose the service type

| The user has | Service type | Runtime mode |
|---|---|---|
| App in a GitHub repo | Git source service (`repoFullName`) | `web` |
| App in a non-GitHub or public repo, or SSH | Git source service (`repoUrl`) | `web` |
| Queue consumer, scheduler, bot, anything with no HTTP | Git source or image, `worker` | `worker` |
| Site that builds to static files | Git source with `staticOutput` | `web` |
| Prebuilt image (`ghcr.io/org/app:latest`) | Docker image service | `web` or `worker` |
| Postgres, MySQL, Redis, MongoDB, TimescaleDB, ClickHouse | Database service | see databases reference |

## 2. Make the repo deployable

Inspect the project and confirm each of these. Fix only what is needed, and tell the user what you changed.

- **Listens on `0.0.0.0` and `$PORT`.** Aeroplane injects `PORT` into web containers. An app bound only to `127.0.0.1` fails the port probe.
- **`internalPort` matches the real listening port.** The API default is `8080`. Set it explicitly.
- **Build method.** If a `Dockerfile` exists at the service root, Aeroplane builds it and ignores install, build, and start overrides. Otherwise Railpack detects the stack. Leave commands blank when auto-detection is right. Add a `Dockerfile` when the stack is unusual or detection fails.
- **Monorepo.** Set `rootDir` to the folder containing the app.
- **Static sites.** Set `staticOutput` to the built folder (`dist`, `build`, `.output/public`). It must contain `index.html`, or the deploy fails. Leave it blank for server-rendered apps, including TanStack Start SSR.
- **Workers.** Use `runtimeMode: "worker"`. They need no port and get no public route. Health means the process stays running.
- **Env vars.** List what the app needs from `.env.example`. Never copy real secrets into the repo.
- **Non-standard Dockerfile location.** Set `dockerfilePath` (relative to the service root) or the `AEROPLANE_DOCKERFILE_PATH` service variable, which wins if both are set.

Build method options: `auto` (default, uses a Dockerfile when present), `dockerfile` (fails if missing), `railpack` (ignores the Dockerfile).

## 3. Create the project and service

Look for an existing project first so you do not create duplicates.

```sh
scripts/aeroplane-api.sh GET /api/projects
scripts/aeroplane-api.sh POST /api/projects '{"name":"Acme","description":"Production"}'
```

Create a GitHub source service. The repo must be visible to the connected GitHub App.

```sh
scripts/aeroplane-api.sh POST /api/projects/PROJECT_ID/services '{
  "name": "web",
  "repoFullName": "acme/web",
  "branch": "main",
  "rootDir": null,
  "runtimeMode": "web",
  "internalPort": 3000,
  "env": [{ "key": "NODE_ENV", "value": "production" }]
}'
```

Optional fields: `installCommand`, `prebuildCommand`, `buildCommand`, `startCommand`, `staticOutput`, `buildMethod`, `dockerfilePath`.

A direct Git URL instead of `repoFullName`:

```json
{ "name": "web", "repoFullName": null, "repoUrl": "https://github.com/acme/web.git",
  "branch": "main", "runtimeMode": "web", "internalPort": 3000 }
```

A Docker image service:

```json
{ "name": "api", "repoUrl": "docker-image", "dockerImage": "ghcr.io/acme/api:latest",
  "branch": "main", "runtimeMode": "web", "internalPort": 8080 }
```

Private images use the **host's** Docker login, so the user must `docker login` on the server first.

The response includes `environmentId` (the default `Production` environment) and, if the server has a wildcard root domain, a **generated hostname named after the service**: a service called `scout-api` gets `scout-api.<root-domain>` as `primaryUrl`, with `preferredDomain.status` `pending` until Caddy has a certificate (usually within a minute if wildcard DNS already exists). Pick service names with that in mind, because the name becomes the URL. To confirm a wildcard root exists, create a service and read `primaryUrl`.

Save the returned `service.id`. You need it for everything else. Do not use `githubToken` on a service unless the user insists, because it stores a credential.

## 3b. Multi-service repos (web, API, worker)

One repo can back several services. Give each its own `rootDir`, and for a second Dockerfile in the same folder set `buildMethod: "dockerfile"` with `dockerfilePath` (for example `Dockerfile.worker`) so `auto` does not pick the default one. A background worker is `runtimeMode: "worker"`. Frontend values that are baked in at build time, such as `NEXT_PUBLIC_*`, must be set on the service **before** its first deploy, because Railpack builds receive the service's variables.

## 4. Env vars and databases first

Set variables and create any database before the first deploy. See `env-domains-tls.md` and `databases-logs-rollback.md`.

## 5. Deploy

```sh
scripts/aeroplane-api.sh POST /api/services/SERVICE_ID/deployments
```

The response has `deployment.id` and status `queued`. Concurrency is limited globally (default 3 slots), and a service never builds twice at once.

Poll until it settles:

```sh
scripts/aeroplane-api.sh GET /api/services/SERVICE_ID/deployments    # newest first, read .deployments[0].status
```

Statuses: `queued` waiting for a slot, `building` working, `running` live, `superseded` replaced by a newer one, `aborted`, `failed`.

Logs:

```sh
scripts/aeroplane-api.sh GET /api/deployments/DEPLOYMENT_ID/logs
```

Abort a stuck one with `POST /api/deployments/DEPLOYMENT_ID/abort`.

## 6. Verify it actually works

```sh
scripts/aeroplane-api.sh GET /api/services/SERVICE_ID/overview     # primaryUrl, domains, env, publicIp
curl -sS -o /dev/null -w '%{http_code}\n' https://THE_PRIMARY_URL
```

Runtime logs stream as Server-Sent Events. Sample a few seconds, then stop:

```sh
curl -N --max-time 10 -H "Authorization: Bearer $AEROPLANE_API_KEY" "$AEROPLANE_URL/api/services/SERVICE_ID/runtime-logs/stream"
```

Do not call it done until the URL answers.

## 7. Push to deploy

When the GitHub App webhook is configured, every push to the service's **branch** on its **repo** queues a deployment. Matching is on `repoFullName` plus `branch`, so the service must be created from a GitHub repo, not a direct Git URL. Manual deploys always work.
