require "test_helper"

class ReminderDispatchJobTest < ActiveJob::TestCase
  test "advances next_send_at and enqueues SendReminderJob only for due reminders" do
    due = reminder_definitions(:one)
    not_due = reminder_definitions(:two)
    due_original = due.next_send_at
    not_due_original = not_due.next_send_at

    assert_enqueued_with(job: SendReminderJob, args: [due.id]) do
      ReminderDispatchJob.perform_now
    end

    assert_equal 1, enqueued_jobs.count { |j| j[:job] == SendReminderJob }

    assert_equal due_original + 1.day, due.reload.next_send_at
    assert_equal not_due_original, not_due.reload.next_send_at
  end

  test "advances next_send_at even when the user has no pending tasks" do
    due = reminder_definitions(:one)
    due.user.tasks.destroy_all
    original = due.next_send_at

    ReminderDispatchJob.perform_now

    assert_equal original + 1.day, due.reload.next_send_at
  end
end
