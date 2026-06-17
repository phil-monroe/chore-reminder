require "test_helper"

class ReminderDefinitionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "index page links back to the user" do
    user = users(:one)

    get user_reminder_definitions_path(user)

    assert_select "a[href='#{user_path(user)}']", text: /Back to #{user.name}/
  end

  test "show page links back to the reminders list" do
    reminder = reminder_definitions(:one)

    get user_reminder_definition_path(reminder.user, reminder)

    assert_select "a[href='#{user_reminder_definitions_path(reminder.user)}']", text: /Back to reminders/
  end

  test "new form's cancel button links to the reminders list" do
    user = users(:one)

    get new_user_reminder_definition_path(user)

    assert_select "a[href='#{user_reminder_definitions_path(user)}']", text: "Cancel"
  end

  test "edit form's cancel button links to the reminder's show page" do
    reminder = reminder_definitions(:one)

    get edit_user_reminder_definition_path(reminder.user, reminder)

    assert_select "a[href='#{user_reminder_definition_path(reminder.user, reminder)}']", text: "Cancel"
  end

  test "send_now enqueues a SendReminderJob for the reminder" do
    reminder = reminder_definitions(:one)

    assert_enqueued_with(job: SendReminderJob, args: [reminder.id]) do
      post send_now_user_reminder_definition_path(reminder.user, reminder)
    end

    assert_redirected_to user_reminder_definition_path(reminder.user, reminder)
  end
end
