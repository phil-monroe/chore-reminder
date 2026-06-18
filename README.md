# Chore Reminder

Self-hosted Rails app: a caregiver maintains an ordered chore list per household member and the app texts the next pending chore on a schedule via Twilio. It's meant to run on a home server for a single household, gated by a single shared username/password (HTTP Basic Auth) rather than per-user accounts.

## Stack

- Rails 8, PostgreSQL
- GoodJob / Solid Cache / Solid Cable (no Redis dependency) — background jobs run in-process alongside the web server, no separate worker
- Phlex-Rails for views, Tailwind CSS (no Node build step)
- `acts_as_list`, `twilio-ruby`, `commonmarker`, `liquid`
- Minitest + Capybara/Cuprite for system tests

## Setup

```
docker-compose up -d   # starts Postgres
bin/setup
```

## Running the app

```
bin/dev/run-all   # web server + Tailwind watcher
```

Local environment variables (e.g. real Twilio credentials) go in an untracked `.env` file at the project root — `dotenv-rails` loads it automatically in development. A baseline `.env` with the vars below is already set up locally; just fill in the blanks. `.env` is gitignored and only loaded in development, never in test (see `CLAUDE.md` for why).

## Running the test suite

```
bin/dev/run-tests
```

Use this instead of calling `bin/rails test` directly. System tests launch a real headless Chrome via Capybara/Cuprite, and this project's test suite has a known failure mode worth knowing about: Rails auto-parallelizes test workers once the suite passes 50 tests, and if multiple workers each launch Chrome at once, one can crash and the whole run hangs indefinitely waiting on a dead worker (it looks like a slow test run, but CPU usage sits near zero — it's actually wedged). `test/test_helper.rb` pins parallel workers to 1 to avoid this, and `bin/dev/run-tests` also clears out any leftover headless Chrome process from a previous interrupted run before each run. It's safe to leave `bin/dev/run-web`/`run-all` running while you run tests — `run-tests` won't touch your dev server. See `CLAUDE.md` for the full details if you hit this.

```
bin/dev/run-tests test/models   # run a subset, same arguments as `bin/rails test`
```

## Running in Docker

The image is published to Docker Hub as [`philmonroe/chore-reminder`](https://hub.docker.com/r/philmonroe/chore-reminder) on every push to `main` (see `.github/workflows/docker-publish.yml`). It's a standalone production image — no Kamal or other deploy tool needed, just `docker run` with environment variables:

```
docker run -d -p 80:80 \
  -e SECRET_KEY_BASE=<output of: bin/rails secret> \
  -e BASIC_AUTH_USERNAME=... -e BASIC_AUTH_PASSWORD=... \
  -e DATABASE_HOST=... -e DATABASE_USERNAME=... -e DATABASE_PASSWORD=... -e DATABASE_NAME=... \
  -e TWILIO_ACCOUNT_SID=... -e TWILIO_AUTH_TOKEN=... -e TWILIO_FROM_NUMBER=... \
  -e APP_HOST=... \
  --name chore-reminder philmonroe/chore-reminder
```

That's it — no separate worker container needed. Background jobs (GoodJob) run in-process inside that same container (see `CLAUDE.md`'s "Background jobs" section). The dashboard is at `/good_job` on the running container.

### Environment variables

| var | purpose |
|---|---|
| `SECRET_KEY_BASE` | required; generate with `bin/rails secret` |
| `BASIC_AUTH_USERNAME` / `BASIC_AUTH_PASSWORD` | required; shared credentials for the whole site |
| `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_USERNAME` / `DATABASE_PASSWORD` / `DATABASE_NAME` | Postgres connection |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM_NUMBER` | Twilio |
| `APP_HOST` | comma-separated host(s) the server accepts requests for; the first is also used for absolute URLs in SMS links |
| `ACTIVE_STORAGE_SERVICE` | `local` or `amazon` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` / `AWS_BUCKET` | S3, only if `ACTIVE_STORAGE_SERVICE=amazon` |
