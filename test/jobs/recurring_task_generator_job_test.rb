require "test_helper"

class RecurringTaskGeneratorJobTest < ActiveJob::TestCase
  test "creates a task for definitions that recur today and skips others" do
    today_def = task_definitions(:one)
    today_def.update!(recurrence_days: [Date.current.wday])
    today_def.tasks.destroy_all

    other_def = task_definitions(:two)
    other_def.update!(recurrence_days: [(Date.current.wday + 1) % 7])
    other_def.tasks.destroy_all

    RecurringTaskGeneratorJob.perform_now

    assert_equal 1, today_def.tasks.count
    assert_equal 0, other_def.tasks.count
  end

  test "is idempotent when run twice on the same day" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [Date.current.wday])
    td.tasks.destroy_all

    RecurringTaskGeneratorJob.perform_now
    RecurringTaskGeneratorJob.perform_now

    assert_equal 1, td.tasks.count
  end
end
