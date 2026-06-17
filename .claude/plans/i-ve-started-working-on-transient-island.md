# Chore Reminder App — Implementation Plan

## Context
This is a fresh `rails new` scaffold (Rails 8.1.3, Postgres, Tailwind, Solid Queue/Cache/Cable already in the Gemfile) with no domain code yet. The goal is a small self-hosted app for a single household: a caregiver maintains an ordered chore list per family member and the app texts the next pending chore on a schedule via Twilio. No auth — it runs on a home server behind the household's own network, so the scope is intentionally minimal (no login, no multi-tenant isolation beyond per-`User` data ownership).

This plan is the full build-out: data model, background jobs, SMS delivery, Phlex/Tailwind views, and tests. The design decisions below were already made by the user (in a prior planning session) to resolve ambiguities in the original spec — implement them as written, they are not open questions.

## Stack
- Rails 8.x — Solid Queue as the Active Job backend (avoids a Redis dependency for a home-server deploy)
- PostgreSQL, configured via `DATABASE_URL`
- Phlex-Rails for views
- Tailwind CSS via `tailwindcss-rails` (no Node build step)
- `acts_as_list` for task ordering
- `twilio-ruby` for SMS
- `commonmarker` for markdown rendering (CommonMark-compliant)
- `liquid` for rendering the per-user reminder message template at send time
- ActiveStorage: local + S3, selected via env var
- Minitest + Capybara/Cuprite for tests

## Current repo state (verified)
- Gemfile already has: `pg`, `tailwindcss-rails`, `solid_cache`, `solid_queue`, `solid_cable`, `capybara`, `selenium-webdriver`. Still need to add: `phlex-rails`, `acts_as_list`, `twilio-ruby`, `commonmarker`, `liquid`, `aws-sdk-s3` (require: false), `cuprite` (test group).
- `config/database.yml` already routes the cache/queue/cable databases to Postgres in production (`chore_reminder_production_cache/queue/cable`) — no fix needed.
- `config/storage.yml` has `test` and `local` Disk services; no `amazon` (S3) entry yet — needs to be added.
- `config/recurring.yml` exists with one example job (`clear_solid_queue_finished_jobs`) — needs the two new entries added alongside it.
- No `app/models`, `app/controllers`, or `app/jobs` beyond the Rails base classes. No `application_system_test_case.rb` yet (needs Cuprite wired in).

## Design decisions
These extend the literal spec where something was required but left unstated. All resolved — implement as written, not as open questions.

1. **`task_definition_id` on `Task`** (nullable FK) — not in the literal field list, but required to satisfy "link to a task definition show page" in the reminder. Ad-hoc tasks with no definition just omit the link.
2. **Idempotent daily task generation** checks the `created_at` date range on `task_definition.tasks` rather than a `scheduled_date` column, since `Task` has no such field per spec. Prevents duplicate generation if the daily job reruns.
3. **No-pending-task behavior**: if a `ReminderDefinition` fires and the user has zero pending tasks, skip sending and just advance `next_send_at`.
4. **ActiveStorage target**: `has_many_attached :images` on `TaskDefinition`, for instructional images referenced from the markdown description.
5. **Task ordering scope**: `acts_as_list` scoped to `:user` across all tasks, done and undone. "Next task" query filters `where(done: false)` on top of position order, so completed tasks need no position cleanup.
6. **`next_send_at` advances at dispatch time, not at successful delivery.** The 15-minute dispatcher advances every due reminder's `next_send_at` by `+1.day` and enqueues a separate `SendReminderJob` per reminder for the actual lookup/render/send. Advancing immediately (a) keeps the poller from re-firing the same due reminder repeatedly, and (b) means a Twilio failure or retry on one recipient can't block or duplicate sends to others in the same 15-minute batch — see Jobs section.
7. **Message wording is configurable per `User`, not per send.** `message_template` is a caregiver-edited Liquid template, fixed for a given user across all sends — this is about avoiding hardcoded strings in code, not introducing per-occurrence variability. Default template uses `{% if link %}` so ad-hoc tasks without a `task_definition` render cleanly with no dangling blank line.

## Data model

### User
| field | type |
|---|---|
| name | string, not null |
| phone_number | string, not null, E.164 format validated |
| message_template | text, not null, default: standard Liquid template (decision #7) |

- `has_many :tasks, dependent: :destroy`
- `has_many :task_definitions, dependent: :destroy`
- `has_many :reminder_definitions, dependent: :destroy`
- `validates :phone_number, format: { with: /\A\+[1-9]\d{6,14}\z/ }` — basic E.164 shape check, not full ITU validation
- validate `message_template` parses as Liquid at save time, so a typo doesn't silently break every future send for that user: call `Liquid::Template.parse(message_template)` in a custom validator, rescue `Liquid::SyntaxError` into `errors.add`
- default `message_template`: `"{{ task_name }}\n\n{% if link %}{{ link }}{% endif %}"` — Liquid variables passed at render time are `task_name` and `link`

### Task
| field | type |
|---|---|
| name | string, not null |
| done | boolean, default: false, not null |
| position | integer, via `acts_as_list` |
| user_id | bigint, FK, not null |
| task_definition_id | bigint, FK, nullable (decision #1) |

- `belongs_to :user`
- `belongs_to :task_definition, optional: true`
- `acts_as_list scope: :user`
- scope `pending -> where(done: false)`
- `Task.next_for(user) = user.tasks.pending.order(:position).first`

### TaskDefinition
| field | type |
|---|---|
| name | string, not null |
| description | text — markdown source |
| recurrence_days | integer array, default: `[]` — 0=Sunday..6=Saturday |
| user_id | bigint, FK, not null |

- `belongs_to :user`
- `has_many :tasks, dependent: :nullify` — generated task instances; migration should add the FK with `on_delete: :nullify` (`t.references :task_definition, foreign_key: { on_delete: :nullify }` on the `tasks` table) so destroying a definition doesn't orphan rows or hard-fail against existing tasks
- validate every `recurrence_days` element is within `0..6`
- `has_many_attached :images` (decision #4)
- `recurs_on?(date) = recurrence_days.include?(date.wday)`
- `rendered_description = Commonmarker.to_html(description).html_safe` — output via Phlex `unsafe_raw`

### ReminderDefinition
| field | type |
|---|---|
| time_of_day | time, not null |
| next_send_at | datetime, not null |
| user_id | bigint, FK, not null |

- `belongs_to :user`
- `before_validation :compute_next_send_at, if: -> { new_record? || time_of_day_changed? }` — recompute on create and whenever `time_of_day` is edited, not just on create, or changing the time in the UI does nothing until the next natural cycle
- `time` columns store a sentinel date (2000-01-01); build the candidate from today's date explicitly rather than comparing the raw column: `candidate = Time.zone.now.change(hour: time_of_day.hour, min: time_of_day.min); self.next_send_at = candidate > Time.zone.now ? candidate : candidate + 1.day`
- `advance! = update!(next_send_at: next_send_at + 1.day)`

## Jobs

### RecurringTaskGeneratorJob
Runs once daily (recommend 00:05, after midnight rollover). The per-definition generation logic lives in `TaskDefinition#generate_task_for_today!` so it can be reused by both the scheduled job and the manual "Generate today's task now" button on the TaskDefinition show page:
- `generate_task_for_today!` — no-ops unless `recurs_on?(Date.current)`; skips if a `Task` already exists for that definition with `created_at` inside today's range; else creates `Task` (`name` copied from definition, `task_definition:`, `user:`, `done: false`) — `acts_as_list` appends to end of that user's order automatically
- The job itself just iterates `TaskDefinition.find_each(&:generate_task_for_today!)`

### ReminderDispatchJob
Runs every 15 minutes. For every `ReminderDefinition.where("next_send_at <= ?", Time.current)`:
- `reminder.advance!` immediately (decision #6) — decouples scheduling from delivery outcome
- `SendReminderJob.perform_later(reminder.id)`

This job touches only `ReminderDefinition` rows and makes no external calls — keep it that way so it has effectively no failure surface of its own.

### SendReminderJob
Takes a `reminder_definition_id`. Resolves the task fresh at execution time, not at dispatch time, since delivery may be delayed by a retry:
- `reminder = ReminderDefinition.find(reminder_definition_id)`
- `task = Task.next_for(reminder.user)`
- if `task` is nil: no-op (decision #3)
- else: render `reminder.user.message_template` via `Liquid::Template.parse(...).render("task_name" => task.name, "link" => link_or_nil)` — `link_or_nil` is `task_definition_url(task.task_definition, host: ENV.fetch("APP_HOST"))` when `task.task_definition` is present, else `nil`; send the rendered body via `Sms::TwilioSender`
- `retry_on Twilio::REST::RestError, wait: :polynomially_longer, attempts: 5` — retries are scoped to this one reminder/recipient and can't re-process or double-send to others in the same dispatch batch

```yaml
# config/recurring.yml (Solid Queue) — verify exact syntax against the Solid Queue version pinned in Gemfile.lock; add alongside the existing clear_solid_queue_finished_jobs entry
production:
  reminder_dispatch:
    class: ReminderDispatchJob
    schedule: every 15 minutes
  recurring_task_generator:
    class: RecurringTaskGeneratorJob
    schedule: "5 0 * * *"
```

## Services

### Sms::TwilioSender
```ruby
module Sms
  class TwilioSender
    def initialize(client: Twilio::REST::Client.new(ENV.fetch("TWILIO_ACCOUNT_SID"), ENV.fetch("TWILIO_AUTH_TOKEN")))
      @client = client
    end

    def send(to:, body:)
      @client.messages.create(from: ENV.fetch("TWILIO_FROM_NUMBER"), to: to, body: body)
    end
  end
end
```
Client is constructor-injected for testability — stub it in tests, no real Twilio calls. Calling job should `rescue Twilio::REST::RestError` and use ActiveJob `retry_on` rather than swallowing failures.

## Views — Phlex + Tailwind

- `ApplicationView < Phlex::HTML` base, including Phlex::Rails helper concerns (`link_to`, route helpers, Turbo Stream helpers)
- `Layouts::ApplicationLayout` — page shell, nav bar (links to Dashboard / Users / a per-user quick switcher), Tailwind link, flash message rendering, yields content. Mobile-first responsive layout — this is likely operated from a phone.
- Per resource (Users, Tasks, TaskDefinitions, ReminderDefinitions): `Index`, `Show`, `Form` (shared new/edit) — rendered from controllers via `render Views::Users::Index.new(users: @users)`
- **Dashboard** (root path) — one card per `User` showing their current next pending task (or an empty state), with an inline "Mark done" button and a link into their full task list. This is the primary screen for day-to-day use.
- Task index: up/down buttons per row hitting `move_higher`/`move_lower` (`acts_as_list`'s built-in methods), and a "done" toggle button per row — both wired as Turbo Stream responses so the list re-renders in place without a full page reload (Turbo is already in the stack, no extra JS needed)
- All destructive actions (`destroy` on any resource) use `data-turbo-confirm` for an inline confirm dialog
- Every index/list view has a written empty state (e.g. "No tasks yet — add one below") rather than a blank page
- TaskDefinition show: renders `rendered_description` via `unsafe_raw`, and lists attached `images` as thumbnails using `image_processing` (already in the Gemfile) — define a `:thumb` variant (`resize_to_limit: [300, 300]`) and link the thumbnail to the full-size blob
- TaskDefinition show and ReminderDefinition show each get a manual trigger button for convenience/testing without waiting for the schedule:
  - TaskDefinition show: "Generate today's task now" → directly runs the same idempotent generation logic used by `RecurringTaskGeneratorJob` for that one definition
  - ReminderDefinition show: "Send now" → enqueues `SendReminderJob` immediately for that reminder, independent of `next_send_at`
- User show: "Send test SMS" button → sends a fixed test message directly through `Sms::TwilioSender` to confirm Twilio credentials/number work, with success/failure flash feedback — this is the fastest way to validate the whole SMS path is configured correctly right after setup
- User form: `message_template` editor is a plain `textarea` with the available variables (`task_name`, `link`) and the current default shown as placeholder/help text directly in the form

## Seed data
`db/seeds.rb` populates a small realistic household so the app is demoable immediately after `db:seed`, with no manual data entry required: 2 `User`s, a few `TaskDefinition`s per user spanning different `recurrence_days` (including one that recurs today, so the dashboard has something to show right away), a couple of ad-hoc `Task`s with no `task_definition`, and one `ReminderDefinition` per user. Idempotent (`find_or_create_by!` on natural keys) so it's safe to rerun.

## Routes
```ruby
root "dashboard#index"

resources :users do
  resources :tasks do
    member do
      patch :move_higher
      patch :move_lower
      patch :toggle_done
    end
  end
  resources :task_definitions do
    member do
      post :generate_now
    end
  end
  resources :reminder_definitions do
    member do
      post :send_now
    end
  end
  member do
    post :send_test_sms
  end
end
```

## Testing

**Unit**
- `User` — validations (name/phone presence, phone format), default `message_template` renders correctly via `Liquid::Template.parse`
- `Task` — validations, `acts_as_list` ordering, `Task.next_for`
- `TaskDefinition` — `recurs_on?` across all 7 days, `rendered_description` output
- `ReminderDefinition` — initial `next_send_at` (today vs. tomorrow branch), `advance!`

**Jobs**
- `RecurringTaskGeneratorJob` — creates tasks for matching definitions, idempotent on same-day rerun, skips non-matching days
- `ReminderDispatchJob` — only enqueues for due reminders, `advance!` is called for every due reminder regardless of whether a task exists, enqueues exactly one `SendReminderJob` per due reminder
- `SendReminderJob` — Liquid-rendered body is correct both with and without a `task_definition` link (covers the `{% if link %}` branch), no-ops cleanly with zero pending tasks, stubbed `Sms::TwilioSender`, retry behavior on a simulated `Twilio::REST::RestError`

**Services**
- `Sms::TwilioSender` — stub Twilio client, assert `from`/`to`/`body`, error propagation

**System (Capybara + Cuprite)**
- Full CRUD per resource: Users, Tasks, TaskDefinitions, ReminderDefinitions
- Task reorder via move_higher/move_lower
- Marking a task done removes it from "next task" eligibility

## Configuration (env vars)

| var | purpose |
|---|---|
| `DATABASE_URL` | Postgres connection |
| `TWILIO_ACCOUNT_SID` | Twilio |
| `TWILIO_AUTH_TOKEN` | Twilio |
| `TWILIO_FROM_NUMBER` | Twilio sending number |
| `APP_HOST` | host for absolute URLs in SMS links |
| `ACTIVE_STORAGE_SERVICE` | `local` or `amazon` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` / `AWS_BUCKET` | S3, only if `ACTIVE_STORAGE_SERVICE=amazon` |
| `RAILS_TIME_ZONE` | app time zone for `time_of_day` / `next_send_at` math |

```yaml
# config/storage.yml — add an `amazon` service alongside the existing test/local Disk services
amazon:
  service: S3
  access_key_id: <%= ENV["AWS_ACCESS_KEY_ID"] %>
  secret_access_key: <%= ENV["AWS_SECRET_ACCESS_KEY"] %>
  region: <%= ENV["AWS_REGION"] %>
  bucket: <%= ENV["AWS_BUCKET"] %>
```
Selected via initializer: `Rails.application.config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "local").to_sym`

## Implementation checklist

### Phase 0 — Project setup
- [x] `rails new` already run with Postgres + Tailwind; Solid Queue/Cache/Cable already in Gemfile and already routed to Postgres in `config/database.yml` — confirmed, no fix needed
- [ ] Add gems: `phlex-rails`, `acts_as_list`, `twilio-ruby`, `commonmarker`, `liquid`, `aws-sdk-s3` (require: false); add `cuprite` to the `test` group
- [ ] `bin/rails generate phlex:install` (confirm exact generator name against the gem's current README before relying on it)
- [ ] Create `app/test/application_system_test_case.rb` (doesn't exist yet) using Cuprite instead of Selenium
- [ ] Add `amazon` S3 service to `config/storage.yml`

### Phase 1 — Models & migrations
- [ ] `User` model + migration (incl. `message_template` text column with Liquid default)
- [ ] `TaskDefinition` model + migration (`recurrence_days` array column, `images` attachment)
- [ ] `Task` model + migration (`task_definition_id`, `acts_as_list`)
- [ ] `ReminderDefinition` model + migration
- [ ] Validations + associations per spec above
- [ ] `Task.next_for`, `TaskDefinition#recurs_on?`, `TaskDefinition#rendered_description`, `TaskDefinition#generate_task_for_today!`, `ReminderDefinition#advance!`
- [ ] `:thumb` image variant on `TaskDefinition#images` (`resize_to_limit: [300, 300]`)
- [ ] `db/seeds.rb` with idempotent demo data (2 users, varied task definitions incl. one recurring today, ad-hoc tasks, reminder definitions)

### Phase 2 — Jobs & services
- [ ] `Sms::TwilioSender`
- [ ] `RecurringTaskGeneratorJob` (thin wrapper over `TaskDefinition#generate_task_for_today!`) + `config/recurring.yml` entry
- [ ] `ReminderDispatchJob` (advance + enqueue only) + `config/recurring.yml` entry
- [ ] `SendReminderJob` (task lookup, Liquid render, Twilio send, `retry_on`)
- [ ] `APP_HOST`-based URL generation for SMS links

### Phase 3 — Routes & controllers
- [ ] Root route → `DashboardController#index`
- [ ] Nested resource routes (above), incl. `toggle_done`, `generate_now`, `send_now`, `send_test_sms` member actions
- [ ] CRUD controllers for all four resources
- [ ] `move_higher` / `move_lower` / `toggle_done` actions on `TasksController`, responding to Turbo Stream
- [ ] `TaskDefinitionsController#generate_now`, `ReminderDefinitionsController#send_now`, `UsersController#send_test_sms`

### Phase 4 — Views (Phlex + Tailwind)
- [ ] `ApplicationView` base + `ApplicationLayout` (nav bar, flash messages, mobile-first layout)
- [ ] `Dashboard::Index` — per-user next-task card with inline done button and empty state
- [ ] Users: Index / Show (incl. "Send test SMS") / Form (incl. `message_template` editor with variable help text)
- [ ] TaskDefinitions: Index / Show (rendered markdown, image thumbnails, "Generate today's task now") / Form (day-of-week checkboxes, image upload)
- [ ] Tasks: Index (reorder buttons, done toggle, Turbo Stream updates, empty state) / Form
- [ ] ReminderDefinitions: Index / Show ("Send now") / Form
- [ ] `data-turbo-confirm` on every destroy action; written empty states on every index view

### Phase 5 — Tests
- [ ] Model unit tests (all four), incl. `generate_task_for_today!`
- [ ] Job tests (both)
- [ ] Service test (`Sms::TwilioSender`)
- [ ] Controller/request tests for manual trigger actions (`generate_now`, `send_now`, `send_test_sms`)
- [ ] System tests (CRUD × 4 resources, reorder flow, done-toggle flow, dashboard rendering, manual trigger buttons)

### Phase 6 — Deploy config
- [ ] `Procfile`: `web: bin/rails server`, `worker: bin/jobs` (Solid Queue)
- [ ] Confirm env var list against Dokku config

## Verification
- `bin/rails db:create db:migrate` runs clean against Postgres
- `bin/rails test` passes for all unit/job/service tests
- `bin/rails test:system` passes for the Capybara/Cuprite suite
- Manually create a User, TaskDefinition (with a recurring day matching today), and ReminderDefinition; run `RecurringTaskGeneratorJob.perform_now` and confirm a Task is created; run `SendReminderJob.perform_now(reminder.id)` with a stubbed `Sms::TwilioSender` and confirm the rendered message body matches the template with/without a task_definition link
