# Environment variables, domains, and TLS

## Environment variables

Variables belong to a **service**. Set them at creation (`env` array) or afterwards.

```sh
# create or update (same endpoint does both)
scripts/aeroplane-api.sh POST /api/services/SERVICE_ID/env '{"key":"NODE_ENV","value":"production"}'

# list them: the overview returns env with ids
scripts/aeroplane-api.sh GET /api/services/SERVICE_ID/overview

# delete one by its id
scripts/aeroplane-api.sh DELETE /api/services/SERVICE_ID/env/ENV_ID
```

- Keys look like `NODE_ENV`: letters, digits, underscores, not starting with a digit. Use upper case.
- Aeroplane **injects `PORT`** into web containers. Do not set `PORT` yourself.
- To copy a whole `.env` file, parse it locally, write one small JSON file per variable, post each with `@file`, and print only key names and results. Never echo values. Strip a leading BOM, skip empty values, and override URLs that point at localhost.
- The dashboard accepts pasted `.env` blocks (`#` lines ignored, duplicates replaced by the last value). The API takes one variable per call, so loop over them.
- Values are masked in the UI but returned by the overview endpoint to authorized callers. Treat the response as sensitive and do not paste it into chat or commit it.
- Redeploy after changing variables. They apply to new containers.

### Reference a database instead of copying its URL

```txt
DATABASE_URL=${postgres-db.POSTGRES_URL}
```

`postgres-db` is the database service's name. The reference follows the database if it is recreated or restored. Ask for suggestions:

```sh
scripts/aeroplane-api.sh GET /api/projects/PROJECT_ID/database-variable-suggestions
scripts/aeroplane-api.sh GET /api/services/SERVICE_ID/suggestion-keys
```

Use these private references when the app and database run on the same Aeroplane server. Keep public database access off unless something outside the server needs it.

### Where secrets go

Put real secrets in Aeroplane service variables. Keep only placeholders in `.env.example` in the repo. Host-level settings (GitHub App credentials, update commands) belong in System Settings or the server environment, not in service variables.

## Domains

Caddy routes traffic and obtains certificates automatically once DNS points at the server. There is nothing to configure for TLS on app domains.

### Generated hostnames

If the owner set a wildcard root such as `*.pilot.example.com`, every web service gets a hostname like `api.pilot.example.com`. Check `primaryUrl` in the service overview. Workers get none.

### Custom domain

1. DNS (the user's registrar): point the hostname at the **server's public IP**.
   ```txt
   A     app.example.com     SERVER_IPV4
   AAAA  app.example.com     SERVER_IPV6
   ```
   `publicIp` in the service overview shows the target.
2. Add it:
   ```sh
   scripts/aeroplane-api.sh POST /api/services/SERVICE_ID/domains '{"hostname":"app.example.com"}'
   ```
   Workers cannot take custom domains.
3. Check status in the overview (`domains[].status`: `active` or pending).
4. Rename or remove with `PATCH` or `DELETE /api/services/SERVICE_ID/domains/DOMAIN_ID`.

### Let Aeroplane create the DNS record

If the owner connected a DNS provider in System Settings (**Cloudflare, Namecheap, or Spaceship**), the A record can be created for them:

```sh
scripts/aeroplane-api.sh POST /api/services/SERVICE_ID/domains/DOMAIN_ID/dns-records '{"providerId":"cloudflare"}'
```

The provider connection itself is browser-only.

### Domain stays pending

Work through this in order:

- The hostname resolves to the server's public IPv4 (and wildcard DNS exists for generated hostnames).
- Ports 80 and 443 are open and nothing else on the server uses them.
- Caddy is running: `cd /opt/aeroplane && sudo docker compose logs -f caddy`.
- The service is deployed and active.
- `internalPort` matches what the app listens on.
- DNS may still be propagating. Wait, then refresh and verify in the dashboard Domains tab.

Local `localhost` domains need no public DNS.

## TLS for databases

Only relevant when a database's public access is enabled. Aeroplane creates a public hostname and Postgres TLS assets. Fetch the CA to verify connections:

```sh
scripts/aeroplane-api.sh GET /api/services/DB_SERVICE_ID/database/tls
scripts/aeroplane-api.sh GET /api/services/DB_SERVICE_ID/database/tls/ca
```
