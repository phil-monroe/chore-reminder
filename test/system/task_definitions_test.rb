require "application_system_test_case"

class TaskDefinitionsSystemTest < ApplicationSystemTestCase
  test "creating a task definition with recurrence and viewing rendered markdown" do
    user = users(:one)

    visit admin_user_task_definitions_path(user)
    click_on "New task definition"

    fill_in "Name", with: "Vacuum the living room"
    fill_in "Description (Markdown)", with: "Use the **upright** vacuum."
    check "Sunday"
    click_on "Create Task definition"

    assert_text "Vacuum the living room"
    assert_selector "strong", text: "upright"
  end

  test "generate today's task now button creates a task when due" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [Date.current.wday])
    td.tasks.destroy_all

    visit admin_user_task_definition_path(td.user, td)
    click_on "Generate today's task now"

    assert_equal 1, td.tasks.count
  end
end
