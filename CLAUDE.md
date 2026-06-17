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

## Running tests

Always run tests through `bin/dev/run-tests`, not `bin/rails test` directly:

```
bin/dev/run-tests                  # full suite (models, jobs, services, controllers, system)
bin/dev/run-tests test/models      # just one directory/file, same as bin/rails test
```

### Why a wrapper script exists

System tests use Capybara/Cuprite, which launches a real headless Chrome process per test session. Two things found in practice make this unsafe to run carelessly:

1. **Parallel test workers + system tests don't mix here.** Rails' test runner auto-parallelizes once the suite crosses 50 tests (`parallelize(workers: ...)` in `test/test_helper.rb`). If multiple workers each launch their own headless Chrome at once, one can crash, and the main process then hangs **indefinitely** waiting on a DRb response from a worker that will never reply — it looks like a slow test run, but it's actually a wedged process burning ~0% CPU. `test/test_helper.rb` pins `workers: 1` to prevent this. Don't raise that number without re-verifying the full suite (system + everything else, run together, past the 50-test threshold) survives several times in a row.
2. **Stray dev-server/Chrome processes from manual testing compound the problem.** If you've been hand-testing with `bin/rails server` in the background and didn't kill it cleanly, or a previous system test run got killed mid-flight, leftover Puma or headless Chrome processes add resource pressure that makes the crash in (1) more likely. `bin/dev/run-tests` kills matching stray processes and clears the stale `tmp/pids/server.pid` before every run.

If a test run ever appears to hang with no CPU usage, suspect this exact failure mode — check for a `druby*` socket among the test process's open files (`lsof -p <pid>`) confirming it's blocked on DRb, kill it, clear stray processes, and rerun via `bin/dev/run-tests`.
