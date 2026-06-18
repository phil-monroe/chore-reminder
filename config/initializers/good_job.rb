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
    recurring_task_generator: {
      cron: "5 0 * * *",
      class: "RecurringTaskGeneratorJob"
    }
  }
end
