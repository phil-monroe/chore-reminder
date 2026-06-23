require "test_helper"

class TaskGenerationDispatchJobTest < ActiveJob::TestCase
  test "advances next_generate_at and generates a task only for due definitions that recur today" do
    due = task_definitions(:one)
    due.update!(recurrence_days: [Date.current.wday])
    due.tasks.destroy_all

    not_due = task_definitions(:two)
    not_due.update!(recurrence_days: [Date.current.wday])
    not_due.tasks.destroy_all

    due_original = due.next_generate_at
    not_due_original = not_due.next_generate_at

    TaskGenerationDispatchJob.perform_now

    assert_equal 1, due.tasks.count
    assert_equal 0, not_due.tasks.count
    assert_equal due_original + 1.day, due.reload.next_generate_at
    assert_equal not_due_original, not_due.reload.next_generate_at
  end

  test "advances next_generate_at even when the definition does not recur today" do
    due = task_definitions(:one)
    due.update!(recurrence_days: [(Date.current.wday + 1) % 7])
    due.tasks.destroy_all
    original = due.next_generate_at

    TaskGenerationDispatchJob.perform_now

    assert_equal original + 1.day, due.reload.next_generate_at
    assert_equal 0, due.tasks.count
  end
end
