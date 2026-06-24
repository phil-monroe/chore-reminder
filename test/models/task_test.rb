require "test_helper"

class TaskTest < ActiveSupport::TestCase
  test "invalid without a name" do
    task = Task.new(name: nil, user: users(:one))
    assert_not task.valid?
  end

  test "valid without a task_definition" do
    task = Task.new(name: "Ad-hoc task", user: users(:one))
    assert task.valid?
  end

  test "acts_as_list orders tasks within a user, appending new tasks to the end" do
    user = users(:one)
    user.tasks.destroy_all
    first = user.tasks.create!(name: "First")
    second = user.tasks.create!(name: "Second")
    third = user.tasks.create!(name: "Third")

    assert_equal [first, second, third], user.tasks.order(:position).to_a
  end

  test ".next_for returns the first pending task by position, skipping done tasks" do
    user = users(:one)
    user.tasks.destroy_all
    user.tasks.create!(name: "Already done", done: true)
    pending_task = user.tasks.create!(name: "Still pending")

    assert_equal pending_task, Task.next_for(user)
  end

  test ".next_for returns nil when there are no pending tasks" do
    user = users(:one)
    user.tasks.destroy_all
    user.tasks.create!(name: "Done", done: true)

    assert_nil Task.next_for(user)
  end

  test "reminder_body renders the message template with the task name and link" do
    task = tasks(:one)

    body = task.reminder_body("{{ task_name }}\n\n{% if link %}{{ link }}{% endif %}")

    assert_includes body, task.name
    assert_includes body, "http://"
  end

  test "reminder_body renders the time estimate when set" do
    task = tasks(:one)
    task.time_estimate_minutes = 15

    body = task.reminder_body("{{ task_name }}{% if time_estimate %} ({{ time_estimate }}){% endif %}")

    assert_equal "#{task.name} (15 min)", body
  end

  test "reminder_body renders cleanly with no time estimate" do
    task = tasks(:one)
    task.time_estimate_minutes = nil

    body = task.reminder_body("{{ task_name }}{% if time_estimate %} ({{ time_estimate }}){% endif %}")

    assert_equal task.name, body
  end

  test "time_estimate_label is nil with no time estimate" do
    task = Task.new(name: "Ad-hoc task", user: users(:one))

    assert_nil task.time_estimate_label
  end

  test "time_estimate_label formats minutes under an hour" do
    task = Task.new(name: "Ad-hoc task", user: users(:one), time_estimate_minutes: 15)

    assert_equal "15 min", task.time_estimate_label
  end

  test "time_estimate_label formats whole hours" do
    task = Task.new(name: "Ad-hoc task", user: users(:one), time_estimate_minutes: 120)

    assert_equal "2 hr", task.time_estimate_label
  end

  test "time_estimate_label formats hours and minutes" do
    task = Task.new(name: "Ad-hoc task", user: users(:one), time_estimate_minutes: 90)

    assert_equal "1 hr 30 min", task.time_estimate_label
  end

  test "name_with_time_estimate appends the label in parentheses when set" do
    task = Task.new(name: "Feed the pets", user: users(:one), time_estimate_minutes: 15)

    assert_equal "Feed the pets (15 min)", task.name_with_time_estimate
  end

  test "name_with_time_estimate is just the name with no time estimate" do
    task = Task.new(name: "Feed the pets", user: users(:one))

    assert_equal "Feed the pets", task.name_with_time_estimate
  end

  test "invalid with a zero or negative time estimate" do
    task = Task.new(name: "Ad-hoc task", user: users(:one), time_estimate_minutes: 0)
    assert_not task.valid?

    task.time_estimate_minutes = -5
    assert_not task.valid?
  end

  test "link_url is nil for an ad-hoc task with no task_definition" do
    task = Task.new(name: "Ad-hoc task", user: users(:one))

    assert_nil task.link_url
  end

  test "link_url is the public unauthenticated page, keyed by the user's id and the task_definition's id by default" do
    task = tasks(:one)

    assert_includes task.link_url, "/#{task.task_definition.user.id}/#{task.task_definition.id}"
  end

  test "link_url uses the user's username instead of their id when present" do
    task = tasks(:one)
    task.task_definition.user.update!(username: "alex")

    assert_includes task.link_url, "/alex/#{task.task_definition.id}"
  end

  test "link_url uses the task_definition's slug instead of its id when present" do
    task = tasks(:one)
    task.task_definition.update!(slug: "feed-the-pets")

    assert_includes task.link_url, "/#{task.task_definition.user.id}/feed-the-pets"
  end
end
