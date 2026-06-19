require "test_helper"

class TaskDefinitionTest < ActiveSupport::TestCase
  test "recurs_on? is true only for days listed in recurrence_days" do
    td = task_definitions(:one)
    td.recurrence_days = [1, 3, 5]

    (0..6).each do |wday|
      date = Date.current.beginning_of_week(:sunday) + wday
      assert_equal [1, 3, 5].include?(wday), td.recurs_on?(date)
    end
  end

  test "invalid with an out-of-range recurrence day" do
    td = task_definitions(:one)
    td.recurrence_days = [7]
    assert_not td.valid?
  end

  test "rendered_description converts markdown to html" do
    td = task_definitions(:one)
    td.description = "**bold** text"
    assert_includes td.rendered_description, "<strong>bold</strong>"
  end

  test "rendered_description is blank for blank description" do
    td = task_definitions(:one)
    td.description = nil
    assert_equal "", td.rendered_description
  end

  test "generate_task_for_today! creates a task only when recurring today and not already generated" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [Date.current.wday])
    td.tasks.destroy_all

    assert_difference -> { td.tasks.count }, 1 do
      td.generate_task_for_today!
    end

    assert_no_difference -> { td.tasks.count } do
      td.generate_task_for_today!
    end
  end

  test "generate_task_for_today! does nothing on a non-recurring day" do
    td = task_definitions(:one)
    non_today = (Date.current.wday + 1) % 7
    td.update!(recurrence_days: [non_today])
    td.tasks.destroy_all

    assert_no_difference -> { td.tasks.count } do
      td.generate_task_for_today!
    end
  end

  test "generate_task_for_today! enqueues a next-task notification when it creates a task" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [Date.current.wday])
    td.user.tasks.destroy_all

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [td.user_id, nil]) do
      td.generate_task_for_today!
    end
  end
end
