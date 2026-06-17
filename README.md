# Chore Reminder

Self-hosted Rails app: a caregiver maintains an ordered chore list per household member and the app texts the next pending chore on a schedule via Twilio. There's no auth — it's meant to run on a home server for a single household.

## Stack

- Rails 8, PostgreSQL
- Solid Queue / Solid Cache / Solid Cable (no Redis dependency)
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

## Running the test suite

```
bin/dev/run-tests
```

Use this instead of calling `bin/rails test` directly. System tests launch a real headless Chrome via Capybara/Cuprite, and this project's test suite has a known failure mode worth knowing about: Rails auto-parallelizes test workers once the suite passes 50 tests, and if multiple workers each launch Chrome at once, one can crash and the whole run hangs indefinitely waiting on a dead worker (it looks like a slow test run, but CPU usage sits near zero — it's actually wedged). `test/test_helper.rb` pins parallel workers to 1 to avoid this, and `bin/dev/run-tests` also clears out any stray dev-server/Chrome processes left over from manual testing before each run, since those add resource pressure that makes the crash more likely. See `CLAUDE.md` for the full details if you hit this.

```
bin/dev/run-tests test/models   # run a subset, same arguments as `bin/rails test`
```
