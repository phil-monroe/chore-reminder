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
    done_task = user.tasks.create!(name: "Already done", done: true)
    pending_task = user.tasks.create!(name: "Still pending")

    assert_equal pending_task, Task.next_for(user)
  end

  test ".next_for returns nil when there are no pending tasks" do
    user = users(:one)
    user.tasks.destroy_all
    user.tasks.create!(name: "Done", done: true)

    assert_nil Task.next_for(user)
  end
end
