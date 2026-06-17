require "application_system_test_case"

class TasksSystemTest < ApplicationSystemTestCase
  test "creating a task, reordering it, and marking it done" do
    user = users(:one)
    user.tasks.destroy_all
    first = user.tasks.create!(name: "First task")
    second = user.tasks.create!(name: "Second task")

    visit user_tasks_path(user)
    assert_text "First task"
    assert_text "Second task"

    within all(".bg-white.border", minimum: 2).last do
      click_on "↑"
    end

    assert_equal [second, first], user.tasks.order(:position).to_a

    within first(".bg-white.border", text: "Second task") do
      click_on "done"
    end

    assert_equal first, Task.next_for(user)
  end

  test "dashboard shows the next pending task for each user and an empty state with none" do
    user = users(:one)
    user.tasks.destroy_all

    visit root_path
    assert_text "No pending tasks. All done!"

    user.tasks.create!(name: "Sweep")
    visit root_path
    assert_text "Sweep"
  end
end
