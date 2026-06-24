# Chore Reminder

Self-hosted Rails app: a caregiver maintains an ordered chore list per household member and the app texts the next pending chore on a schedule via Twilio. Runs on a home server for a single household, gated by a single shared username/password (see "Authentication" below) rather than per-user accounts.

## Stack

- Rails 8, PostgreSQL (configured via `DATABASE_HOST`/`DATABASE_PORT`/`DATABASE_USERNAME`/`DATABASE_PASSWORD`/`DATABASE_NAME`, see `config/database.yml`)
- GoodJob (Active Job backend, runs in-process — see "Background jobs" below) / Solid Cache / Solid Cable (no Redis dependency)
- Phlex-Rails for views, Tailwind CSS (no Node build step)
- `acts_as_list`, `twilio-ruby`, `commonmarker`, `liquid`
- Minitest + Capybara/Cuprite for system tests

## Running locally

- `bin/dev/run-all` — runs the web server + Tailwind watcher via Foreman/Procfile.dev
- `bin/dev/run-web` — web server only
- Postgres runs via `docker-compose up -d` (see `docker-compose.yml`)

Keep one of these running in the background at all times for smoke/verification testing — don't start and stop it per change. Rails' code reloading picks up controller/model/view changes automatically, so a running server stays current. **Always restart it** after any change to `Gemfile`/`Gemfile.lock` (run `bundle install` first), `.env`, or an initializer/other config file — all of these are only read at boot, so a running server silently keeps stale values otherwise.

**Always run `bin/rails tailwindcss:build` after modifying any view file** (any new/changed Tailwind class), then re-check rendered output, even if `bin/dev/run-all`'s watcher is also running — don't assume the watcher already caught it before you verify. `app/assets/builds/tailwind.css` is a compiled artifact: a class that isn't in it yet doesn't apply, and the breakage can be subtle (e.g. a missing `flex-col` falls back to row direction, not an obviously broken page) — caught this exact case when a layout edit shipped with `flex`/`flex-1` rendering as side-by-side columns because the build was stale.

### .env

`dotenv-rails` is in the `:development` group only (Gemfile), loading an untracked `.env` at the project root for real local credentials (Twilio, etc). It's deliberately **not** in `:test`: dotenv sets a var present in `.env` with no value (e.g. `TWILIO_ACCOUNT_SID=`) to an empty string, not unset — `ENV.fetch("TWILIO_ACCOUNT_SID")` then returns `""` instead of raising `KeyError`. Several tests assert on the friendly "Twilio is not configured" error that only fires on that `KeyError`; with dotenv loaded in test, those same requests instead hit Twilio's API with empty credentials and get a `Twilio::REST::RestError` (404) — a different failure path, and one that depends on whatever happens to be in a given developer's local `.env`. Test behavior must not depend on local secrets. Found this exact regression by running the suite right after adding dotenv.

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

## Linting

Style/lint is [Standard](https://github.com/standardrb/standard) (`standardrb`), not RuboCop directly — `bin/standardrb` (or `bin/standardrb --fix` to autocorrect). It's a curated, mostly-non-configurable RuboCop config, so `.standard.yml` should stay minimal; it currently just enables the `standard-rails` plugin for Rails-aware cops. `standardrb` still delegates to RuboCop's CLI internally, which matters for one thing: its cache reads the env var `RUBOCOP_CACHE_ROOT` by that exact name regardless of which wrapper invokes it (see `.github/workflows/ci.yml`'s lint job) — don't rename it when touching CI caching.

## Authentication

The caregiver-facing admin area — everything under `/admin`, including the mounted GoodJob dashboard at `/admin/good_job` — sits behind a single shared password, configured via the required `ADMIN_PASSWORD` env var — there are no per-user accounts. Logging in (`SessionsController#new`/`#create`, form at `GET`/`POST /login`) compares the submitted password against `ADMIN_PASSWORD` with `ActiveSupport::SecurityUtils.secure_compare` (a constant-time comparison, so a wrong guess can't be timed to leak how many leading characters matched) and, on success, sets `session[:admin_authenticated] = true`; `#destroy` (`DELETE /logout`) clears it with `reset_session`.

The actual gate is Rack middleware (`config/initializers/admin_auth.rb`, `app/middleware/admin_session_gate.rb`), not a controller `before_action`, specifically because GoodJob's mounted engine has its own controllers that don't inherit from `ApplicationController` — only middleware sees every request regardless of which Rails app/engine handles it. It checks `session[:admin_authenticated]` directly off `env["rack.session"]` (populated by `ActionDispatch::Session::CookieStore`, which runs earlier in the middleware stack since `config.middleware.use` always appends) and redirects to `/login` if it's missing, rather than rendering a 401 itself — there's a real login page to redirect to, unlike the old Basic Auth prompt. The middleware gates by a simple `/admin` path-prefix check rather than an enumerated skip list, since everything outside `/admin` (the health check, the login page, the Twilio webhook, and the public per-task page below) is meant to be reachable with no session at all. `SessionsController`'s routes (`/login`, `/logout`) are deliberately outside `/admin` so the gate never blocks reaching the login form itself. All admin routes live under `namespace :admin do ... end` in `config/routes.rb`, with controllers under `Admin::` (e.g. `Admin::UsersController`) and views under `Views::Admin::` (e.g. `Views::Admin::Users::Show`) to match. The bare `/` redirects to `/admin`, which redirects to `/login` if not yet authenticated.

`dotenv-rails` doesn't load in `:test` (see below), so `test/test_helper.rb` sets a fixed `ADMIN_PASSWORD` value itself before Rails boots, and prepends a module onto `ActionDispatch::Integration::Session#process` (reopening the class directly would replace its `process` method instead of wrapping it, breaking `super`) to log in via a real `POST /login` before each integration test's first request — otherwise every existing controller test would need its own login call. System tests log in by actually visiting `/login` and submitting the form in `test/application_system_test_case.rb`'s `setup`, since Capybara's real-browser driver doesn't go through Rails' test request helpers at all (so it can't reuse the same `process`-wrapping trick) but does share cookies with the app the same as a real browser would.

## Inbound SMS replies

`Integrations::TwilioController#sms_inbound_webhook` (mounted at `POST /integrations/twilio/sms_inbound_webhook`, see `config/routes.rb`) lets a household member reply to a reminder text to act on their list, instead of only ever using the web UI: `DONE` marks their current (top, pending) task done, `SKIP` moves it to the bottom of their list, `NEXT` lists their next 5 pending tasks, `LIST` lists all pending tasks (capped at `MAX_LIST_SIZE`, 20, with a trailing "...and N more." if truncated), and `ADD <name>` appends a new task. Commands are matched case-insensitively. The user is looked up by the inbound `From` number (`User#phone_number`); an unrecognized number gets a generic reply rather than any indication of whether the number is in use. The parsing/dispatch and all the reply text live in `User::HandleInboundSms`, following the command pattern above — `call` returns the reply body as a string rather than raising, since producing a reply *is* the success case here, not a side effect to confirm.

`NEXT` and `LIST` are deliberately kept separate rather than merged into one command: `NEXT` is the low-key default — useful for a household member who can find a long list overwhelming — while `LIST` is an explicit ask to see everything when they want the full picture.

This endpoint can't go through the admin area's shared Basic Auth (Twilio has no way to supply those credentials, and the endpoint lives outside `/admin` anyway — see "Authentication" above) or Rails' CSRF protection (no session, no authenticity token) — `skip_forgery_protection` handles the latter. In their place, the controller verifies Twilio's `X-Twilio-Signature` header via `Twilio::Security::RequestValidator`, using the same `TWILIO_AUTH_TOKEN` env var as `Sms::TwilioSender` — this is what actually proves a request came from Twilio, since the URL itself isn't secret. Signature validation is keyed off `request.request_parameters` rather than `params`, since the former is exactly the raw posted body Twilio signed, while the latter also includes the route/format params Rails injects.

`test/test_helper.rb` sets a fixed `TWILIO_AUTH_TOKEN` for the same dotenv-related reason it sets the Basic Auth credentials (see "Running locally" above) — and so that controller tests can compute a matching signature for requests they send.

`User::HandleInboundSms.new(..., deliver_reply: false)` (the default) just logs the reply directly rather than sending it through `Sms::TwilioSender` — correct for the real Twilio webhook, where the reply is delivered by Twilio itself responding to the TwiML the controller renders, so actually re-sending it would double-deliver. The web UI's "simulate a text reply" form (see "Conversation view" below) has no such webhook response to ride along on, so it passes `deliver_reply: true`, which instead routes the reply through `User::SendMessage` — a real Twilio send and the same logging-after-success guarantee as every other outbound message.

## Realtime "next task" notifications

Any modification that can change which task is next for a user — completing/skipping/adding/editing/deleting/reordering a task (`Admin::TasksController`), an inbound SMS command (`User::HandleInboundSms`), or a recurring task generating for the day (`TaskDefinition#generate_task_for_today!`) — enqueues `NotifyNextTaskChangedJob` with the user id and whatever the next task's id *was* right before the change. This closes the gap between a change happening and the next scheduled `ReminderDispatchJob` run (up to 15 minutes later, see "Background jobs" above), texting the new next task right away instead.

The job (really `User::NotifyIfNextTaskChanged`, which it delegates to) re-checks `Task.next_for(user)` against that previous id and only sends a text if they differ — comparing ids rather than re-fetching/diffing the previous task itself, since by the time the job runs the old "next" task may have been completed, moved, or deleted, and its id is all that's needed for the comparison. This is why, for example, renaming a task elsewhere in the list, or editing a task that wasn't already first, enqueues the job but it harmlessly no-ops. `Task#reminder_body`/`Task#link_url` (also used by `SendReminderJob`) build the actual message text, so both the scheduled reminder and this realtime path render the same way.

Deliberately *not* folded into `User::HandleInboundSms`'s own TwiML reply (e.g. DONE's reply is just `Marked "X" done.`, not also `Next up: Y.`) — the async job is the single place that decides whether the next task changed and is worth a text, so a web UI change and a text-message change behave identically instead of needing the comparison written twice.

Known limitation: two list modifications in quick succession (before either's `NotifyNextTaskChangedJob` has run) can each capture the same pre-change "previous next task id," so both jobs independently see a change and both send a text — a harmless but visible duplicate notification. Not coalesced; accepted as an edge case rather than worth the added complexity of debouncing/locking.

## Conversation view

`GET /admin/users/:id/conversation` (`Admin::UsersController#conversation`, linked from the user's show page) renders a chat-style view of every `Message` for that user — inbound texts (blue, right-aligned) and outbound texts/reminders (white, left-aligned), oldest first, styled by `Message#outbound?`. The message panel auto-scrolls to the newest message on load (`scroll-to-bottom` Stimulus controller, `app/javascript/controllers/scroll_to_bottom_controller.js`, setting `scrollTop = scrollHeight` on connect). `Message` is a simple log: `user`, `direction` (`enum` of `inbound`/`outbound`), `body`, `created_at` — no association back to the `Task`/`ReminderDefinition` that prompted it.

Every real outbound send is logged from one place, `User::SendMessage#call`, after the underlying `Sms::TwilioSender#send` succeeds (so a raised error never logs a message that wasn't actually sent) — this is why `SendReminderJob` routes through `User::SendMessage` rather than calling `Sms::TwilioSender` directly, the same as `NotifyNextTaskChangedJob`/welcome messages. Inbound messages and their reply are instead logged directly in `User::HandleInboundSms#call` (the inbound body, then the TwiML reply text), since that reply is delivered by Twilio itself rather than via `Sms::TwilioSender`.

The conversation page has a single form (`POST /admin/users/:id/send_inbound_message`) that lets a caregiver simulate a household member's text reply from the web UI — useful when they're physically with that person rather than texting them. Every message a caregiver types here is the *inbound* side of the conversation (what the household member would have sent); `User::HandleInboundSms` produces the *outbound* reply, the same as the real Twilio webhook does, with `deliver_reply: true` (see "Inbound SMS replies" above) so that reply is also actually sent as a real text — not just displayed — the same as a real text-message exchange. There's deliberately no separate "send an outbound message" form here; outbound messages only ever exist as replies to something inbound, mirroring how a real conversation works. (The standalone `new_message`/`send_message` page is unrelated — a one-off message with no expected reply, e.g. an ad-hoc note — and isn't part of this chat view.)

## Host configuration (`APP_HOST`)

`APP_HOST` is a comma-separated list of hostnames (`AppHost.all`/`AppHost.primary` in `app/services/app_host.rb`) used for two things: every listed host is added to `config.hosts` (Action Dispatch's DNS-rebinding protection) in `config/initializers/app_host.rb`, in both development and production, and the *first* host is used to build absolute links in SMS messages (`SendReminderJob#link_for`). Left unset, link generation falls back to `localhost:3000` and host checking stays at Rails' defaults (open in production, localhost-only in development) — this is deliberately opt-in so existing single-host deployments aren't affected.

`config/initializers/app_host.rb` and `config/initializers/basic_auth.rb` both `require_relative` their app classes (`AppHost`, `BasicAuthAdminGate`) instead of referencing the bare constant. Zeitwerk's main autoloader isn't set up yet while `config/initializers/*` run — that happens later, in the finisher — so a bare constant reference at this point raises `NameError: uninitialized constant`.

## SMS safety: fictional numbers never get a real send

`Sms::TwilioSender#send` no-ops (just logs) for any `to` number matching `+1555` (`Sms::TwilioSender::FICTIONAL_NUMBER`) — the NANP-reserved-for-fiction area/exchange convention, and what `db/seeds.rb`'s demo data uses. This guard is unconditional: it applies even with real Twilio credentials configured (e.g. in a filled-in `.env`), so seeding or testing against demo users can never actually deliver a text. Only real-looking numbers (like the actual household member set up in seeds) go through to Twilio.

## Background jobs (GoodJob)

GoodJob is the Active Job backend, configured in `config/initializers/good_job.rb` to run with `execution_mode: :async_server` in development and production — meaning it executes jobs and cron schedules in background threads inside whichever process boots Rails (the web/Puma process), not a separate worker process. There is no `bin/jobs`, no worker entry in `Procfile`, and no worker container in the Dockerfile — that's the point: one process to run, one process to deploy.

`:async_server` (vs plain `:async`) specifically limits this to the actual web server process, so a one-off `rails console`/`runner` invocation doesn't also spin up a redundant cron scheduler. Test is untouched by this — it's deliberately excluded from the `if Rails.env.development? || Rails.env.production?` guard in the initializer, so it keeps GoodJob's own built-in default for test (`execution_mode: :inline`), and `assert_enqueued_with`/etc. swap in the ActiveJob `:test` adapter regardless.

Recurring jobs (`ReminderDispatchJob` every 15 minutes, `RecurringTaskGeneratorJob` daily) are configured as GoodJob cron entries in the same initializer (`config.good_job.cron`), not a separate YAML file. The dashboard is mounted at `/admin/good_job` (`config/routes.rb`) — behind the same Basic Auth gate as the rest of the admin area (see "Authentication" above).

`config/puma.rb` doesn't need a GoodJob plugin/hook: GoodJob auto-starts its async executors via its own Railtie once Rails finishes booting, and our Puma config runs single-process (no `workers`/forking) so there's no cluster lifecycle to coordinate.

## Docker image

The `Dockerfile` builds a standalone production image — no Kamal or other deploy tool required, just `docker run` with environment variables. It's a single process/container: the web server and GoodJob both run there (see "Background jobs" above).

`SECRET_KEY_BASE` must be set explicitly (e.g. `bin/rails secret`) since the image ships without `config/master.key` (gitignored, excluded via `.dockerignore`) — there's deliberately no `RAILS_MASTER_KEY`/credentials path for this app.

`config/database.yml`'s `production` section reuses the same `DATABASE_HOST`/`DATABASE_PORT`/`DATABASE_USERNAME`/`DATABASE_PASSWORD`/`DATABASE_NAME` vars as development/test (it used to hardcode `chore_reminder_production` and a separate `CHORE_REMINDER_DATABASE_PASSWORD` var — fixed because that silently ignored the documented env vars). The Solid Cache/Cable databases (GoodJob just uses the primary database — see above) default to `#{DATABASE_NAME}_cache`/`_cable`, overridable via `CACHE_DATABASE_NAME`/`CABLE_DATABASE_NAME`.

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
