# Per-definition time-of-day task generation

## Context

Task definitions currently recur on specific days (`recurrence_days`) but generate exactly once a day, via a single daily cron job (`RecurringTaskGeneratorJob`) firing at 00:05 America/New_York. A caregiver can't have two similar tasks fire at different times of day — e.g. "Wash dishes AM" at 10am and "Wash dishes PM" at 4pm — so an unfinished morning task either blocks the evening one or sits incomplete all day. This change gives each `TaskDefinition` its own `time_of_day`, generated/checked every 15 minutes (mirroring how `ReminderDefinition`/`ReminderDispatchJob` already do "next fire at" scheduling), so multiple definitions per day at different times become possible. Task generation must remain completely unaffected by snoozing (`User#snoozed?` continues to gate only `SendReminderJob`).

Two related decisions made with the user:
- Existing task definitions backfill to `time_of_day: 08:00` (a deliberate small behavior shift from the old 00:05 Eastern, chosen for a friendlier default rather than exact parity).
- While here, unify ad-hoc `.strftime` calls across the admin UI (reminder definitions, task definitions, conversation view, snooze messages) onto `I18n.l` with named formats in `config/locales/en.yml`, for consistency. Note: `Admin::TaskDefinitionsController`/`Admin::ReminderDefinitionsController` already wrap actions in `Time.use_zone(@user.time_zone)` via the `ControllerWithUser` concern (`app/controllers/concerns/controller_with_user.rb`), and Rails' `time_zone_aware_attributes` already makes `:time`/`:datetime` columns zone-aware — confirmed via `bin/rails runner` that `time_of_day`/`next_send_at` already render in the household member's zone correctly today. So this is purely a formatting-consistency cleanup, not a timezone-correctness fix.

## 1. Migration

New file `db/migrate/<timestamp>_add_time_of_day_and_next_generate_at_to_task_definitions.rb`, single migration (no zero-downtime/rolling-deploy concerns for this self-hosted single-instance app — same directness as `CreateReminderDefinitions`):

```ruby
class AddTimeOfDayAndNextGenerateAtToTaskDefinitions < ActiveRecord::Migration[8.1]
  def up
    add_column :task_definitions, :time_of_day, :time
    add_column :task_definitions, :next_generate_at, :datetime

    execute "UPDATE task_definitions SET time_of_day = '08:00:00'"

    TaskDefinition.reset_column_information
    TaskDefinition.find_each { |td| td.update_column(:next_generate_at, td.send(:compute_next_generate_at_value)) }

    change_column_null :task_definitions, :time_of_day, false
    change_column_null :task_definitions, :next_generate_at, false
  end

  def down
    remove_column :task_definitions, :time_of_day
    remove_column :task_definitions, :next_generate_at
  end
end
```

The migration runs before `time_of_day` is backfilled in-process, so rather than coupling to `TaskDefinition::ComputeNextGenerateAt` (which reads `time_of_day` off the record), just replicate the same two-line computation directly against the hardcoded `08:00` backfill value:

```ruby
TaskDefinition.find_each do |td|
  zone = td.user.time_zone_object
  candidate = zone.now.change(hour: 8, min: 0)
  next_generate_at = (candidate > zone.now) ? candidate : candidate + 1.day
  td.update_column(:next_generate_at, next_generate_at)
end
```

## 2. Business logic as command classes (not model methods)

Per this codebase's command-pattern convention (see CLAUDE.md "Service classes: prefer the command pattern", and `User::SendMessage`/`User::HandleInboundSms`/`User::NotifyIfNextTaskChanged` as existing examples — callers instantiate these directly; `User` itself has no wrapper instance methods delegating to them), the new scheduling logic — and the existing `generate_task_for_today!` logic, since this feature is the reason it's being called from a new place — moves off `TaskDefinition` and into three command classes under `app/models/task_definition/`. `TaskDefinition` itself gains no new public instance methods for this feature; only a `before_validation` callback (which Rails requires to be a method on the model) that delegates to a command.

**`app/models/task_definition/compute_next_generate_at.rb`** (`TaskDefinition::ComputeNextGenerateAt`):
```ruby
class TaskDefinition::ComputeNextGenerateAt
  def initialize(task_definition:)
    @task_definition = task_definition
  end

  def call
    return if @task_definition.time_of_day.blank?

    zone = @task_definition.user.time_zone_object
    candidate = zone.now.change(hour: @task_definition.time_of_day.hour, min: @task_definition.time_of_day.min)
    @task_definition.next_generate_at = (candidate > zone.now) ? candidate : candidate + 1.day
  end
end
```

**`app/models/task_definition/advance_next_generate_at.rb`** (`TaskDefinition::AdvanceNextGenerateAt`):
```ruby
class TaskDefinition::AdvanceNextGenerateAt
  def initialize(task_definition:)
    @task_definition = task_definition
  end

  def call
    @task_definition.update!(next_generate_at: @task_definition.next_generate_at + 1.day)
  end
end
```

**`app/models/task_definition/generate_for_today.rb`** (`TaskDefinition::GenerateForToday`) — replaces the existing `generate_task_for_today!` model method with identical logic, just relocated:
```ruby
class TaskDefinition::GenerateForToday
  def initialize(task_definition:)
    @task_definition = task_definition
  end

  def call
    return unless @task_definition.recurs_on?(Date.current)
    return if @task_definition.tasks.pending.exists?

    user = @task_definition.user
    previous_next_task_id = Task.next_for(user)&.id
    task = @task_definition.tasks.create!(name: @task_definition.name, user: user, done: false)
    NotifyNextTaskChangedJob.perform_later(user.id, previous_next_task_id)
    task
  end
end
```

**`app/models/task_definition.rb`** changes:
```ruby
validates :time_of_day, presence: true

before_validation :compute_next_generate_at, if: -> { new_record? || time_of_day_changed? }
```
```ruby
private

def compute_next_generate_at
  TaskDefinition::ComputeNextGenerateAt.new(task_definition: self).call
end
```
Remove the `generate_task_for_today!` public method entirely — replaced by the command above. `recurs_on?`, `rendered_description`, and the slug logic stay as-is (simple derivations/queries that genuinely fit as AR methods, unlike the scheduling/generation logic).

**Update all existing callers of `generate_task_for_today!`** to instantiate the command instead:
- `app/controllers/admin/task_definitions_controller.rb` `generate_now` action: `TaskDefinition::GenerateForToday.new(task_definition: @task_definition).call`.
- `db/seeds.rb`: `[feed_pets, trash].each { |td| TaskDefinition::GenerateForToday.new(task_definition: td).call }`.
- `test/models/task_definition_test.rb`: the five `generate_task_for_today!` tests move to a new `test/models/task_definition/generate_for_today_test.rb` (see §9), calling `TaskDefinition::GenerateForToday.new(task_definition: td).call` instead of `td.generate_task_for_today!`. Remove those five tests from `task_definition_test.rb`, keeping only `recurs_on?`/`rendered_description`/slug tests there.

`ReminderDefinition#advance!`/`#compute_next_send_at` are intentionally left untouched as model methods — out of scope, pre-existing, and not part of this feature's "new business logic."

## 3. New job — `app/jobs/task_generation_dispatch_job.rb`

Mirrors `ReminderDispatchJob`'s structure, calling the two commands directly/synchronously (not enqueued) — same as the admin `generate_now` action does, since generation is a fast DB-only operation, unlike an actual Twilio send:

```ruby
class TaskGenerationDispatchJob < ApplicationJob
  queue_as :default

  def perform
    TaskDefinition.where("next_generate_at <= ?", Time.current).find_each do |task_definition|
      TaskDefinition::AdvanceNextGenerateAt.new(task_definition: task_definition).call
      TaskDefinition::GenerateForToday.new(task_definition: task_definition).call
    end
  end
end
```

No snooze check anywhere in this job — generation stays unaffected by `User#snoozed?`/`snoozed_until`, per the spec.

## 4. Cron — `config/initializers/good_job.rb`

Replace the `recurring_task_generator` entry (and its Fugit-timezone-gotcha comment, which no longer applies since this job's cron is a plain UTC interval like `reminder_dispatch`'s — `next_generate_at` already encodes the user's zone) with:

```ruby
task_generation_dispatch: {
  cron: "*/15 * * * *",
  class: "TaskGenerationDispatchJob"
}
```

Delete entirely (fully superseded, confirmed only referenced by themselves + the cron initializer):
- `app/jobs/recurring_task_generator_job.rb`
- `test/jobs/recurring_task_generator_job_test.rb`

## 5. Admin UI

- **`app/controllers/admin/task_definitions_controller.rb`**: permit `:time_of_day` in `task_definition_params`.
- **`app/views/admin/task_definitions/form.rb`**: add a time field block (copy `Views::Admin::ReminderDefinitions::Form`'s `time_of_day` block verbatim), placed after the "Recurs on" checkboxes and before the images field.
- **`app/views/admin/task_definitions/show.rb`**: add a small info block above/near the description showing `time_of_day` and `next_generate_at`, formatted via `l` (see §6) — mirror `Views::Admin::ReminderDefinitions::Show`'s layout.
- **`app/views/admin/task_definitions/index.rb`**: extend `recurrence_summary`'s line to also show the time, e.g. `"#{recurrence_summary(td)} at #{l(td.time_of_day, format: :time_of_day)}"`.

## 6. I18n.l formatting cleanup

Add to `config/locales/en.yml`:

```yaml
en:
  time:
    formats:
      time_of_day: "%-l:%M %p"
      short_with_time: "%a %b %-d, %-l:%M %p"
```

Replace existing ad-hoc `.strftime` calls with `l(value, format: :time_of_day)` / `l(value, format: :short_with_time)`:
- `app/views/admin/reminder_definitions/index.rb` (lines 22-23): `rd.time_of_day.strftime("%I:%M %p")` → `l(rd.time_of_day, format: :time_of_day)`; `rd.next_send_at.strftime(...)` → `l(rd.next_send_at, format: :short_with_time)`.
- `app/views/admin/reminder_definitions/show.rb` (lines 11, 18): same two formats.
- `app/views/admin/task_definitions/index.rb` / `show.rb` (new usages from §5): use the same named formats.
- `app/views/admin/users/show.rb` (line 31) and `app/models/user/handle_inbound_sms.rb` (line 122): snooze message `"#{time.in_time_zone(@user.time_zone_object).strftime("%-I:%M %p on %b %-d")}"` — reformat the displayed text to use the new `short_with_time`-style ordering for consistency (`"#{I18n.l(time.in_time_zone(...), format: :short_with_time)}"`), adjusting the surrounding sentence wording only if needed to read naturally with the new date/time order. `handle_inbound_sms.rb` is a plain Ruby model, not a view, so use `I18n.l` (not the `l` view helper).
- `app/views/admin/users/conversation.rb` (line 41): `message.created_at.strftime("%b %-d, %-I:%M %p")` → introduce one more format (`conversation_timestamp: "%b %-d, %-l:%M %p"`) since its date/time order differs from `short_with_time`, or confirm with a quick look whether reusing `short_with_time` (which leads with weekday) reads acceptably here — likely wants its own shorter format without the weekday, since this is a dense per-message timestamp. Add `conversation_timestamp: "%b %-d, %-l:%M %p"` and use `l(message.created_at, format: :conversation_timestamp)`.

Keep this section's scope tight: only touch call sites that already do bare `.strftime` on a time/datetime value for display — don't reformat anything else.

## 7. Seeds — `db/seeds.rb`

`TaskDefinition.find_or_create_by!` blocks for "Feed the pets" / "Take out the trash" need a `time_of_day` set (now required), e.g. `td.time_of_day = "08:00"` and `td.time_of_day = "18:00"` respectively (illustrative AM/PM split, matching the feature's own example). Also update the generation call per §2: `[feed_pets, trash].each { |td| TaskDefinition::GenerateForToday.new(task_definition: td).call }`.

## 8. Fixtures — `test/fixtures/task_definitions.yml`

```yaml
one:
  name: Feed the pets
  description: "Fill **both** bowls."
  recurrence_days: []
  time_of_day: 2000-01-01 08:00:00
  next_generate_at: <%= 1.day.ago %>
  user: one

two:
  name: Take out the trash
  description: "Bins to the curb."
  recurrence_days: []
  time_of_day: 2000-01-01 08:15:00
  next_generate_at: <%= 1.day.from_now %>
  user: two
```
(`one` due/past, `two` not-yet-due — mirrors `reminder_definitions.yml`'s split, giving the new job test a "due" and "not due" fixture for free.)

## 9. Tests

- **New `test/models/task_definition/compute_next_generate_at_test.rb`** (`TaskDefinition::ComputeNextGenerateAtTest`), mirroring `reminder_definition_test.rb`'s four `next_send_at` cases but calling the command directly, e.g.:
  ```ruby
  test "sets next_generate_at to today when the time of day has not yet passed" do
    travel_to Time.zone.local(2026, 6, 17, 6, 0, 0) do
      td = task_definitions(:one)
      td.time_of_day = "08:00"
      TaskDefinition::ComputeNextGenerateAt.new(task_definition: td).call
      assert_equal Time.zone.local(2026, 6, 17, 8, 0, 0), td.next_generate_at
    end
  end
  ```
  (today-not-passed, today-passed-uses-tomorrow, computed-in-user's-zone — the "recompute on edit" case is covered instead by the model's `before_validation` callback test below, since that's where the recompute-on-change behavior actually lives.)
- **New `test/models/task_definition_test.rb` addition**: one test confirming the `before_validation` callback fires the command on `time_of_day` change, e.g. `"recomputes next_generate_at when time_of_day is edited"` (create, then `update!(time_of_day: ...)`, assert `next_generate_at` changed accordingly) — keep this one in the main model test file since it's testing the model's callback wiring, not the command's internals.
- **New `test/models/task_definition/advance_next_generate_at_test.rb`** (`TaskDefinition::AdvanceNextGenerateAtTest`): one test, `TaskDefinition::AdvanceNextGenerateAt.new(task_definition: td).call` moves `next_generate_at` forward by exactly 1 day.
- **New `test/models/task_definition/generate_for_today_test.rb`** (`TaskDefinition::GenerateForTodayTest`): move the five existing `generate_task_for_today!` tests here from `test/models/task_definition_test.rb` verbatim, replacing `td.generate_task_for_today!` calls with `TaskDefinition::GenerateForToday.new(task_definition: td).call`.
- **`test/models/task_definition_test.rb`**: remove the five `generate_task_for_today!` tests (moved above); keep `recurs_on?`/`rendered_description`/slug/`to_param`/`find_by_param!` tests as-is, plus the one new callback-wiring test from above.
- **New `test/jobs/task_generation_dispatch_job_test.rb`**, mirroring `reminder_dispatch_job_test.rb`'s two tests:
  - advances `next_generate_at` and generates a task only for the due definition that also recurs today; the not-due definition is untouched.
  - advances `next_generate_at` even when the definition doesn't recur today (no task created).
- **Delete `test/jobs/recurring_task_generator_job_test.rb`**.
- No new controller test strictly required for the time field (existing controller tests don't cover `recurrence_days` round-tripping either) — skip unless asked.

## Verification

1. `bin/rails db:migrate` then `bin/rails db:seed` (confirm no `RecordInvalid` from the new required `time_of_day`).
2. `bin/dev/run-tests` — full suite green, including new model/job tests.
3. `bin/standardrb`.
4. `bin/rails tailwindcss:build` only if any new Tailwind classes are introduced in the form/show/index edits (unlikely — copying existing classes).
5. Manually exercise in browser (`bin/dev/run-web`, admin Basic Auth): edit a task definition's time of day, confirm the show/index pages render the new time via the `l(...)` formats; run `bin/rails runner 'TaskGenerationDispatchJob.perform_now'` (or wait for cron) and confirm a task generates only for definitions whose `next_generate_at` is due and which `recurs_on?` today; confirm `next_generate_at` advances by exactly 1 day either way.
6. Confirm snoozing a user (`SNOOZE`/`UNSNOOZE` SMS or admin) has zero effect on whether `TaskGenerationDispatchJob` generates tasks.
