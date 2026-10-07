# Databases, logs, and recovering from a bad deploy

## Databases

A database is a service inside the project with `repoFullName: "database:<engine>"`.

| Engine id | Default port | Notes |
|---|---:|---|
| `database:postgres` | 5432 | Logical replication, backups |
| `database:timescale` | 5432 | Postgres family |
| `database:mysql` | 3306 | Browse, SQL console, backups |
| `database:redis` | 6379 | Key browser, backups |
| `database:mongodb` | 27017 | Collections, backups |
| `database:clickhouse` | 8123 | Browse and SQL console, **no backups yet** |

### Create Postgres

```sh
scripts/aeroplane-api.sh POST /api/projects/PROJECT_ID/services '{
  "name": "postgres-db",
  "repoFullName": "database:postgres",
  "repoUrl": "database",
  "branch": "main",
  "internalPort": 5432,
  "databasePublicEnabled": false,
  "env": [
    { "key": "POSTGRES_DB", "value": "app" },
    { "key": "POSTGRES_USER", "value": "postgres" },
    { "key": "POSTGRES_PASSWORD", "value": "GENERATE_A_LONG_RANDOM_VALUE" }
  ]
}'
```

- **Generate the password**, for example `openssl rand -base64 24`. Never reuse or invent a weak one.
- The API schema defaults `databasePublicEnabled` to **true**. Pass `false` explicitly unless the user needs outside access, then confirm with them first.
- Other engines use their own variables (`REDIS_PASSWORD`, `MONGO_INITDB_ROOT_PASSWORD`, and so on). Aeroplane generates engine-specific variables on creation.
- Then **deploy the database service** (`POST /api/services/DB_ID/deployments`) before the app that needs it. Databases run in a container with a persistent Docker volume.
- Point the app at it with `${postgres-db.POSTGRES_URL}` (see `env-domains-tls.md`).

Redeploying a database replaces its container and can interrupt connections. Schedule it carefully.

### Browse and edit data

```txt
GET    /api/services/DB_ID/database/tables
GET    /api/services/DB_ID/database/rows
POST   /api/services/DB_ID/database/query      relational engines only
POST|PATCH|DELETE /api/services/DB_ID/database/rows
```

Editing and deleting rows changes real data. Confirm before write operations.

### Imports

`POST /api/services/DB_ID/database/import/postgres-url`, `.../import/redis-url`, and Railway variants. They can replace existing data, so confirm first.

## Backups

Targets are `disk`, `r2`, or `disk+r2`. R2 must be connected in System Settings first. Automatic daily, weekly, or monthly schedules are off by default.

```sh
scripts/aeroplane-api.sh GET  /api/services/DB_ID/database/backups
scripts/aeroplane-api.sh POST /api/services/DB_ID/database/backups              # take one now
scripts/aeroplane-api.sh PATCH /api/services/DB_ID/database/backups/settings '{...}'
scripts/aeroplane-api.sh GET  /api/services/DB_ID/database/backups/BACKUP_ID/download
```

Restoring (`POST .../backups/BACKUP_ID/restore`) and deleting a backup are **destructive: confirm with the user first**. A backup that exists is not a recovery plan until a restore has been tried.

Engines: Postgres/Timescale use `pg_dump`, MySQL `mysqldump`, MongoDB `mongodump`, Redis an RDB dump.

## Logs

| You want | Use |
|---|---|
| Why a deploy failed (clone, build, pull, health check) | `GET /api/deployments/DEPLOYMENT_ID/logs` |
| Watch a deploy live | `GET /api/deployments/DEPLOYMENT_ID/stream` (Server-Sent Events) |
| What the running app prints | `GET /api/services/SERVICE_ID/runtime-logs/stream` (Server-Sent Events) |
| Aeroplane, Caddy, BuildKit themselves | on the server: `sudo journalctl -u aeroplane -f` and `cd /opt/aeroplane && sudo docker compose logs -f caddy buildkit` |

Stream endpoints never end by themselves, so always bound them:

```sh
curl -N --max-time 15 -H "Authorization: Bearer $AEROPLANE_API_KEY" "$AEROPLANE_URL/api/deployments/DEPLOYMENT_ID/stream"
```

If a deploy failed and the user has an AI provider configured in System Settings, `POST /api/deployments/DEPLOYMENT_ID/explain-failure` returns a summary, likely cause, and suggested fix. It needs write access and a provider; otherwise read the logs yourself.

## Rolling back

Be accurate about what exists:

- **A failed rollout rolls back by itself.** For web services Aeroplane starts the new container beside the old one, probes the port, and only then moves traffic. If the new one never answers, the old one keeps serving.
- **There is no API to deploy an older commit or switch to a previous deployment.** Every deploy builds the head of the configured branch.
- **To undo a release that deployed fine but is wrong:** `git revert` the bad commit (or `git reset` and force-push only if the user explicitly asks), push, and let the push deploy. Or trigger a manual deploy after fixing the branch.
- **To stop an in-flight deploy:** `POST /api/deployments/DEPLOYMENT_ID/abort`. Queued ones are marked aborted, and building ones are asked to stop.
- **A status of `superseded`** just means a newer deployment became live.
- **Databases do not roll back.** Restore from a backup, which is destructive.

## Moving and deleting

`POST /api/services/SERVICE_ID/transfer {"targetProjectId":"..."}` moves a service between projects. `DELETE /api/services/SERVICE_ID` and `DELETE /api/projects/PROJECT_ID` remove services, domains, variables, deployments, and logs. **Always confirm before deleting.**
