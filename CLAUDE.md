# Chore Reminder

Self-hosted Rails app: a caregiver maintains an ordered chore list per household member and the app texts the next pending chore on a schedule via Twilio. No auth — runs on a home server for a single household.

## Stack

- Rails 8, PostgreSQL (configured via `DATABASE_HOST`/`DATABASE_PORT`/`DATABASE_USERNAME`/`DATABASE_PASSWORD`/`DATABASE_NAME`, see `config/database.yml`)
- Solid Queue / Solid Cache / Solid Cable (no Redis dependency)
- Phlex-Rails for views, Tailwind CSS (no Node build step)
- `acts_as_list`, `twilio-ruby`, `commonmarker`, `liquid`
- Minitest + Capybara/Cuprite for system tests

## Running locally

- `bin/dev/run-all` — runs the web server + Tailwind watcher via Foreman/Procfile.dev
- `bin/dev/run-web` — web server only
- Postgres runs via `docker-compose up -d` (see `docker-compose.yml`)

Keep one of these running in the background at all times for smoke/verification testing — don't start and stop it per change. Rails' code reloading picks up controller/model/view changes automatically, so a running server stays current. Only restart it after a `Gemfile` change (`bundle install`) or an initializer/config change, since those are only read at boot.

## Running tests

Always run tests through `bin/dev/run-tests`, not `bin/rails test` directly:

```
bin/dev/run-tests                  # full suite (models, jobs, services, controllers, system)
bin/dev/run-tests test/models      # just one directory/file, same as bin/rails test
```

### Why a wrapper script exists

System tests use Capybara/Cuprite, which launches a real headless Chrome process per test session.

**Parallel test workers + system tests don't mix here.** Rails' test runner auto-parallelizes once the suite crosses 50 tests (`parallelize(workers: ...)` in `test/test_helper.rb`). If multiple workers each launch their own headless Chrome at once, one can crash, and the main process then hangs **indefinitely** waiting on a DRb response from a worker that will never reply — it looks like a slow test run, but it's actually a wedged process burning ~0% CPU. `test/test_helper.rb` pins `workers: 1` to prevent this — that's the actual fix. Don't raise that number without re-verifying the full suite (system + everything else, run together, past the 50-test threshold) survives several times in a row.

`bin/dev/run-tests` additionally kills leftover headless Chrome processes and clears the stale `tmp/pids/server.pid` before each run, in case a previous system test run got killed mid-flight. It deliberately does **not** kill Puma processes by name — that pattern can't distinguish a crashed leftover test server from your actively running `bin/dev/run-web`/`run-all` session, and killing the latter out from under you would be its own bug. Running the dev server and `bin/dev/run-tests` at the same time is safe.

If a test run ever appears to hang with no CPU usage, suspect this exact failure mode — check for a `druby*` socket among the test process's open files (`lsof -p <pid>`) confirming it's blocked on DRb, kill it, and rerun via `bin/dev/run-tests`.

## Docker image

The `Dockerfile` builds a standalone production image — no Kamal or other deploy tool required, just `docker run` with environment variables. The same image runs both the web process (default `CMD`) and the Solid Queue worker (override the command to `bin/jobs`); see the comment at the top of the `Dockerfile` for a runnable example.

`SECRET_KEY_BASE` must be set explicitly (e.g. `bin/rails secret`) since the image ships without `config/master.key` (gitignored, excluded via `.dockerignore`) — there's deliberately no `RAILS_MASTER_KEY`/credentials path for this app.

`config/database.yml`'s `production` section reuses the same `DATABASE_HOST`/`DATABASE_PORT`/`DATABASE_USERNAME`/`DATABASE_PASSWORD`/`DATABASE_NAME` vars as development/test (it used to hardcode `chore_reminder_production` and a separate `CHORE_REMINDER_DATABASE_PASSWORD` var — fixed because that silently ignored the documented env vars). The Solid Cache/Queue/Cable databases default to `#{DATABASE_NAME}_cache`/`_queue`/`_cable`, overridable via `CACHE_DATABASE_NAME`/`QUEUE_DATABASE_NAME`/`CABLE_DATABASE_NAME`.

`.github/workflows/docker-publish.yml` builds and pushes the image to Docker Hub as `philmonroe/chore-reminder` (multi-arch: amd64 + arm64) on every push to `main` and on `v*.*.*` tags. Requires `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` repo secrets.

A running container exposes `GIT_SHA`, `GIT_REF`, and `GIT_COMMIT_MESSAGE` env vars (`docker exec <container> env | grep ^GIT_`) identifying exactly which commit it was built from. The workflow passes these as `--build-arg`s from `github.sha`/`github.ref_name`/the commit subject; they default to empty strings for local `docker build` runs unless you pass them yourself.

### Caching

Both apt package installs and `bundle install` use BuildKit `--mount=type=cache` mounts (not just layer caching) so repeated builds skip redownloading/recompiling unchanged dependencies — this matters most for native-extension gems (`pg`, `nokogiri`, `commonmarker`) that are slow to compile from source. Verified locally: a cold build took ~12 minutes; touching `Gemfile.lock` (forcing `bundle install` to actually re-run, not just hit the layer cache) and rebuilding took ~10 seconds.

The bundle cache is mounted at a path separate from `BUNDLE_PATH`, then copied into `BUNDLE_PATH` (a normal committed layer) once `bundle install` finishes — cache-mounted content is never part of the final image, so gems have to land somewhere real before later stages and the final `COPY --from=build` can see them. The cache is keyed by `$TARGETARCH` since this image builds for both amd64 and arm64, and compiled extensions aren't portable between them.

`cache-from`/`cache-to: type=gha` in the workflow persists regular layer caching across separate CI runs (e.g. an unchanged `Gemfile.lock` skips `bundle install` entirely). Whether BuildKit's mount caches specifically also survive across separate GitHub-hosted runners depends on the `gha` backend/BuildKit version; the mount cache's larger benefit is guaranteed for local rebuilds and within a single multi-platform build.

## Service classes: prefer the command pattern

When behavior doesn't naturally belong as an AR model method or a controller action — sending a message, composing one operation out of another, anything with real inputs and one obvious entry point — write it as a small command class instead of a model instance method or a class-level "service" with multiple public methods:

- Namespace it under the model it's most associated with: `app/models/user/send_message.rb` defining `User::SendMessage`, autoloaded by Zeitwerk the same way `app/models/user.rb` defines `User`.
- All inputs come in as keyword args to `initialize`; the only public entry point is a no-arg `call`. Don't add other public methods — if you need to expose an intermediate result, that's a sign the class should split.
- Compose commands by calling one from another's `call`, passing through whatever was passed to the outer command (see `User::SendWelcomeMessage`, which just builds the canned body and delegates to `User::SendMessage`).
- Make collaborators (an SMS client, a mailer, anything with an external side effect) an injectable keyword arg so tests can substitute a fake and assert on exactly what it was called with — see `sender:` on `User::SendMessage`.
- **Don't give an injectable arg a default that has a side effect** (e.g. `sender: Sms::TwilioSender.new`) — Ruby evaluates default arguments eagerly at call time, before the method body runs, so a default like that constructs (and in this app's case, fails on missing Twilio env vars) before any validation in `call` gets a chance to run. Default to `nil` and construct the real collaborator lazily inside `call`: `(@sender || Sms::TwilioSender.new).send(...)`.
- Controllers/jobs catch the command's own raised errors (e.g. `User::SendMessage::BlankBodyError`) the same way they catch lower-level errors like `Twilio::REST::RestError` — commands raise to signal failure, they don't return a status object.
