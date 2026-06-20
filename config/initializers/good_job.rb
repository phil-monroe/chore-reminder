# GoodJob runs in-process inside whichever process boots Rails — no separate
# worker process/container, no bin/jobs. :async_server specifically limits
# that to the actual web server process (e.g. not a `rails console`/`runner`
# invocation), so cron jobs can't end up scheduled redundantly from a
# one-off script. This only applies to development/production: test relies
# on GoodJob's own default of :inline for that environment, and the
# ActiveJob :test adapter takes over within `assert_enqueued_with` blocks
# regardless.
if Rails.env.development? || Rails.env.production?
  Rails.application.config.good_job.execution_mode = :async_server

  Rails.application.config.good_job.enable_cron = true
  Rails.application.config.good_job.cron = {
    reminder_dispatch: {
      cron: "*/15 * * * *",
      class: "ReminderDispatchJob"
    },
    # Fugit (which GoodJob's cron parsing delegates to) resolves a bare cron
    # string like "5 0 * * *" in UTC, not the server's local time or this
    # app's config.time_zone ("UTC" - unrelated, that only affects
    # Time.zone-aware app code, not Fugit's own cron parsing) - so without an
    # explicit zone, this ran at 00:05 UTC, several hours off from midnight
    # for a US Eastern household. The trailing zone name is Fugit's own
    # documented extension for pinning a cron string to a specific IANA
    # timezone regardless of the server's actual system/container timezone.
    recurring_task_generator: {
      cron: "5 0 * * * America/New_York",
      class: "RecurringTaskGeneratorJob"
    }
  }
end
