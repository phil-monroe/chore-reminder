require "test_helper"

class OneTimeReminderDispatchJobTest < ActiveJob::TestCase
  test "destroys due reminders and enqueues SendOneTimeReminderJob only for them" do
    due = one_time_reminders(:one)
    not_due = one_time_reminders(:two)

    assert_enqueued_with(job: SendOneTimeReminderJob, args: [due.user_id]) do
      OneTimeReminderDispatchJob.perform_now
    end

    assert_equal 1, enqueued_jobs.count { |j| j[:job] == SendOneTimeReminderJob }
    assert_not OneTimeReminder.exists?(due.id)
    assert OneTimeReminder.exists?(not_due.id)
  end
end
