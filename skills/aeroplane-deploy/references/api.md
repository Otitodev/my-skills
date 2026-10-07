# API reference (condensed)

Base URL is `$AEROPLANE_URL`. The API uses the same `/api/*` endpoints as the dashboard. Use `scripts/aeroplane-api.sh`, or curl with `Authorization: Bearer $AEROPLANE_API_KEY` (`X-API-Key` also works).

## Access

- **`Read`** keys may call `GET` only. **`Read and write`** keys may call `GET`, `POST`, `PATCH`, `DELETE`.
- **Project scope.** A key limited to specific projects can only touch those. Service and deployment routes are resolved back to their project. Such keys **cannot create projects**.
- **Browser-session only (an API key always gets 403):** everything under `/api/system/*`, API key creation and revocation, GitHub browsing (`/api/github/repos`, `/branches`, `/directories`), `/api/integrations/*` (Railway, Vercel imports), and onboarding, login, logout, setup.
- Public: `GET /api/health` returns `{"ok":true}`. The GitHub webhook uses a signature instead of a key.

Errors are `{"error":"message"}`:

| Status | Meaning |
|---|---|
| 401 `Authentication required` | no key sent |
| 401 `Invalid or expired API key` | wrong, revoked, or expired |
| 403 `This API key is read-only` | write call with a read key |
| 403 `This API key cannot access that project` | key scoped elsewhere |
| 403 `This endpoint requires a browser session` | session-only endpoint |
| 409 | abort not possible in the current state, or a conflict |

## Environments (newer servers)

Newer Aeroplane servers give every project environments, `Production` (the default) and `Development`. Project responses include `environments`, and each service has an `environmentId`. Creating a service without one puts it in the default environment, which is what you want for a normal deploy. The docs this skill was written from predate this, so check `GET /api/projects/:slug` and trust the live response over the older reference pages.

## Sending request bodies safely

The helper's third argument is the JSON body, or `@file.json` to read it from a file. **Prefer `@file` when the body contains secrets**, so values are not on a command line, and **always on Windows**: when a caller launches the helper from another program (for example Python's `subprocess`), inline JSON can lose its quotes and arrive as an empty body, and Aeroplane answers that with a 500 (not a 400). Write the JSON to a temp file, pass `@/path/to/file.json`, and delete the file afterwards.

## Projects

| Call | Access | Notes |
|---|---|---|
| `GET /api/projects` | read | each project includes its `services` |
| `POST /api/projects` | write, all-projects key | `{name, description?}` |
| `GET /api/projects/:projectSlug` | read | by **slug** |
| `PATCH /api/projects/:projectId` | write | by **id**, `{name?, description?}` |
| `DELETE /api/projects/:projectId` | write | removes services, domains, vars, deployments. Confirm first |
| `GET /api/projects/:projectId/database-variable-suggestions` | read | `${db.VAR}` references |

## Services

| Call | Access | Notes |
|---|---|---|
| `POST /api/projects/:projectId/services` | write | source, Docker image, or database. Returns `{service}` with 201 |
| `GET /api/services/:serviceId/overview` | read | service, recent deployments, env, domains, `publicIp` |
| `PATCH /api/services/:serviceId` | write | change branch, rootDir, commands, port, build method, runtime mode, static output |
| `POST /api/services/:serviceId/transfer` | write | `{targetProjectId}`, key needs both projects |
| `DELETE /api/services/:serviceId` | write | Confirm first |
| `GET /api/services/:serviceId/suggestion-keys` | read | variable reference keys |

Create and update fields: `name`, `repoFullName`, `repoUrl`, `dockerImage`, `branch` (default `main`), `rootDir`, `installCommand`, `prebuildCommand`, `buildCommand`, `startCommand`, `staticOutput`, `buildMethod` (`auto`, `dockerfile`, `railpack`), `dockerfilePath`, `runtimeMode` (`web` or `worker`), `internalPort` (1 to 65535, default 8080), `env` (create only), plus database fields (`databasePublicEnabled`, `databasePublicHostname`, `postgresLogicalReplicationEnabled`). To clear a nullable field on update, send `null`. `detectedBuildMethod` in responses reports what the last deploy actually used.

## Deployments

| Call | Access | Notes |
|---|---|---|
| `POST /api/services/:serviceId/deployments` | write | queues a deploy of the branch head. No body. 201 |
| `GET /api/services/:serviceId/deployments` | read | newest first, up to 30 |
| `POST /api/deployments/:deploymentId/abort` | write | 202, or 409 if not abortable |
| `GET /api/deployments/:deploymentId/logs` | read | `{logs:[{line,stream,createdAt}]}` |
| `GET /api/deployments/:deploymentId/stream` | read | Server-Sent Events: `snapshot`, `log`, `ping` |
| `GET /api/services/:serviceId/runtime-logs/stream` | read | Server-Sent Events: `snapshot`, `log`, `status` |
| `POST /api/deployments/:deploymentId/explain-failure` | write | needs an AI provider configured |

## Environment and domains

| Call | Access | Notes |
|---|---|---|
| `POST /api/services/:serviceId/env` | write | `{key,value}`, creates or updates |
| `DELETE /api/services/:serviceId/env/:envId` | write | |
| `POST /api/services/:serviceId/domains` | write | `{hostname}`. Not for workers |
| `PATCH /api/services/:serviceId/domains/:domainId` | write | `{hostname}` |
| `DELETE /api/services/:serviceId/domains/:domainId` | write | |
| `POST /api/services/:serviceId/domains/:domainId/dns-records` | write | `{providerId}`: `cloudflare`, `namecheap`, `spaceship`. Provider must be connected in System Settings |

Read env vars and domains from `GET /api/services/:serviceId/overview`.

## Databases

All under `/api/services/:serviceId/database/`: `tables`, `rows` (GET, POST, PATCH, DELETE), `query` (POST), `backups` (GET, POST), `backups/settings` (PATCH), `backups/:backupId/download` (GET), `backups/:backupId/restore` (POST), `backups/:backupId` (DELETE), `tls` and `tls/ca` (GET), `imports` (GET), and `import/postgres-url`, `import/redis-url`, `import/railway`, `import/redis-railway` (POST). Also `GET /api/services/:serviceId/import-sources`.

## Not available over the API

Rolling back to an earlier deployment, deploying a specific commit, system settings, and key management. See `databases-logs-rollback.md` for how to recover instead.

Authoritative source: the Aeroplane repository (`website/src/content/docs/docs/reference/` for the docs, `src/server/index.ts` for routes).
