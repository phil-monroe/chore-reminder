# Running Chore Reminder in Docker

Chore Reminder ships as a single standalone production image — [`philmonroe/chore-reminder`](https://hub.docker.com/r/philmonroe/chore-reminder) on Docker Hub — published on every push to `main` and on `v*.*.*` tags (see `.github/workflows/docker-publish.yml`). There's no separate worker container: background jobs (GoodJob) run in-process alongside the web server inside that one container (see `CLAUDE.md`'s "Background jobs" section), and no Kamal or other deploy tool is required — just `docker run` or `docker compose` with environment variables.

## Quick start with `docker run`

```
docker run -d -p 80:80 \
  -e SECRET_KEY_BASE=<output of: bin/rails secret> \
  -e BASIC_AUTH_USERNAME=... -e BASIC_AUTH_PASSWORD=... \
  -e DATABASE_HOST=... -e DATABASE_USERNAME=... -e DATABASE_PASSWORD=... -e DATABASE_NAME=... \
  -e TWILIO_ACCOUNT_SID=... -e TWILIO_AUTH_TOKEN=... -e TWILIO_FROM_NUMBER=... \
  -e APP_HOST=... \
  --name chore-reminder philmonroe/chore-reminder
```

This assumes a Postgres server already exists somewhere reachable as `DATABASE_HOST`. If you don't have one yet, use Docker Compose instead so Postgres comes up alongside the app.

## Example Docker Compose configuration

```yaml
services:
  app:
    image: philmonroe/chore-reminder
    restart: unless-stopped
    ports:
      - "80:80"
    environment:
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      BASIC_AUTH_USERNAME: ${BASIC_AUTH_USERNAME}
      BASIC_AUTH_PASSWORD: ${BASIC_AUTH_PASSWORD}
      DATABASE_HOST: db
      DATABASE_USERNAME: ${DATABASE_USERNAME:-chore_reminder}
      DATABASE_PASSWORD: ${DATABASE_PASSWORD:-password}
      DATABASE_NAME: ${DATABASE_NAME:-chore_reminder_production}
      TWILIO_ACCOUNT_SID: ${TWILIO_ACCOUNT_SID}
      TWILIO_AUTH_TOKEN: ${TWILIO_AUTH_TOKEN}
      TWILIO_FROM_NUMBER: ${TWILIO_FROM_NUMBER}
      APP_HOST: ${APP_HOST}
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:17
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DATABASE_USERNAME:-chore_reminder}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD:-password}
      POSTGRES_DB: ${DATABASE_NAME:-chore_reminder_production}
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DATABASE_USERNAME:-chore_reminder}"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  db_data:
```

Put real values in a `.env` file next to this `docker-compose.yml` (Compose loads it automatically) and run:

```
docker compose up -d
```

`DATABASE_HOST` is set to `db` — the Compose service name — rather than a host/IP, since both containers share the Compose network. The `db` service here is intentionally close to this repo's own development `docker-compose.yml`, just promoted to a `production`-named database and paired with the app container instead of running standalone.

Solid Cache and Solid Cable use the same Postgres server, in databases named `#{DATABASE_NAME}_cache`/`_cable` by default (overridable via `CACHE_DATABASE_NAME`/`CABLE_DATABASE_NAME`) — no extra services needed for them.

## Environment variables

| var | purpose |
|---|---|
| `SECRET_KEY_BASE` | required; generate with `bin/rails secret` |
| `BASIC_AUTH_USERNAME` / `BASIC_AUTH_PASSWORD` | required; shared credentials for the whole site |
| `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_USERNAME` / `DATABASE_PASSWORD` / `DATABASE_NAME` | Postgres connection |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM_NUMBER` | Twilio |
| `APP_HOST` | comma-separated host(s) the server accepts requests for; the first is also used for absolute URLs in SMS links |
| `ACTIVE_STORAGE_SERVICE` | `local` or `amazon` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` / `AWS_BUCKET` | S3, only if `ACTIVE_STORAGE_SERVICE=amazon` |

## Verifying which commit a running container was built from

Every image is built with `GIT_SHA`, `GIT_REF`, and `GIT_COMMIT_MESSAGE` build args from the triggering commit:

```
docker exec chore-reminder env | grep ^GIT_
```

## Image identification

A running container exposes the `/up` health check route unauthenticated (it's excluded from the site's shared Basic Auth — see `CLAUDE.md`'s "Authentication" section), so it can be pointed at by uptime monitors or a Compose `healthcheck` without credentials.
