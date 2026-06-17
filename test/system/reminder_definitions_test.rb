require "application_system_test_case"

class ReminderDefinitionsSystemTest < ApplicationSystemTestCase
  test "creating a reminder definition" do
    user = users(:one)

    visit user_reminder_definitions_path(user)
    click_on "New reminder"

    fill_in "Time of day", with: "2024-01-01 07:30"
    click_on "Create Reminder definition"

    assert_text "07:30 AM"
  end
end
