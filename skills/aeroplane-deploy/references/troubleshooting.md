# Troubleshooting

Start with the **deployment log** for the failed deployment. Then the runtime log. Then server logs. See `databases-logs-rollback.md` for the commands.

| Symptom | Likely cause and fix |
|---|---|
| Deploy `failed`, log mentions BuildKit or the builder is unreachable | `deploy-buildkit` is down or Docker is stopped. On the server: `cd /opt/aeroplane && sudo docker compose ps` and `logs buildkit`. `BUILDKIT_HOST` is normally `tcp://127.0.0.1:1234`. |
| Build starts but "root directory" or files are missing | Wrong `rootDir` for a monorepo. Set it to the folder that holds the app, then redeploy. |
| Container starts, but the deploy fails the port probe | The app listens on a different port than `internalPort`, or binds `127.0.0.1` only. Read the runtime log for the real port, bind `0.0.0.0`, use `$PORT`, and fix `internalPort` with `PATCH /api/services/ID`. |
| Used a Dockerfile but custom start command is ignored | Expected. Install, build, and start overrides apply only to Railpack builds. Put the command in the Dockerfile, or set `buildMethod: "railpack"`. |
| Wrong builder used | Check `detectedBuildMethod`. `auto` picks the Dockerfile whenever one exists at the service root. Pin `buildMethod`, or set `dockerfilePath` for a non-standard location. |
| Static deploy fails | The output folder has no `index.html`, the build command did not create it, or the app is server-rendered. Fix `staticOutput`, or clear it and run as a web service. |
| Deploy stays `queued` | All global slots are busy (default 3). Wait, or abort another deployment. A service also never builds twice at once. |
| App is `running` but the URL is wrong or 502 | Check `primaryUrl` in the overview, `internalPort`, the runtime log, and that the domain is `active`. |
| Domain stuck pending | See "Domain stays pending" in `env-domains-tls.md`. Usually DNS not pointing at the server's IPv4, or ports 80/443 blocked. |
| Push does not deploy | The GitHub App webhook is not set up or lacks a secret (the endpoint returns 503), the service was created from a direct Git URL, or the pushed branch is not the service's branch. Manual deploy still works. |
| `401` or `403` from the API | See the error table in `api.md`. A project-scoped key cannot create projects. System routes need a browser session. |
| `Authentication required` even though the key is set | The key is not in this session's environment. Variables set after the session started are not visible. Restart the terminal or session. |
| Database app cannot connect | Deploy the database service first. Use the private `${db.POSTGRES_URL}` reference. Public hostnames need a wildcard root domain. |
| Backup fails | Database not deployed, engine unsupported (ClickHouse), R2 not connected for `r2` or `disk+r2`, or the disk is full. With `disk+r2` the local backup can succeed while the R2 upload fails. |
| Private image will not pull | The server's Docker is not logged in to that registry. The user must `docker login` on the server. |
| Private SSH repo will not clone | The host needs SSH credentials for it. Or use the GitHub App instead. |
| System update refuses to apply | The install checkout in `/opt/aeroplane/source` is dirty or has diverged. The user resolves it on the server. |

## When you are stuck

Do not retry the same deploy repeatedly. Read the log, state the cause you found, change one thing, and redeploy. If the cause is not in these references, say so and point the user at the repository docs rather than guessing.
