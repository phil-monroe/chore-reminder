require "test_helper"

class TaskDefinition::GenerateForTodayTest < ActiveSupport::TestCase
  test "creates a task only when recurring today and not already generated" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [Date.current.wday])
    td.tasks.destroy_all

    assert_difference -> { td.tasks.count }, 1 do
      TaskDefinition::GenerateForToday.new(task_definition: td).call
    end

    assert_no_difference -> { td.tasks.count } do
      TaskDefinition::GenerateForToday.new(task_definition: td).call
    end
  end

  test "does not generate a new task while a previous one is still pending, even from an earlier day" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [Date.current.wday])
    td.tasks.destroy_all
    td.tasks.create!(name: td.name, user: td.user, done: false, created_at: 3.days.ago)

    assert_no_difference -> { td.tasks.count } do
      TaskDefinition::GenerateForToday.new(task_definition: td).call
    end
  end

  test "generates a new task once the previous one is done, even from an earlier day" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [Date.current.wday])
    td.tasks.destroy_all
    td.tasks.create!(name: td.name, user: td.user, done: true, created_at: 3.days.ago)

    assert_difference -> { td.tasks.count }, 1 do
      TaskDefinition::GenerateForToday.new(task_definition: td).call
    end
  end

  test "does nothing on a non-recurring day" do
    td = task_definitions(:one)
    non_today = (Date.current.wday + 1) % 7
    td.update!(recurrence_days: [non_today])
    td.tasks.destroy_all

    assert_no_difference -> { td.tasks.count } do
      TaskDefinition::GenerateForToday.new(task_definition: td).call
    end
  end

  test "enqueues a next-task notification when it creates a task" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [Date.current.wday])
    td.user.tasks.destroy_all

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [td.user_id, nil]) do
      TaskDefinition::GenerateForToday.new(task_definition: td).call
    end
  end
end
