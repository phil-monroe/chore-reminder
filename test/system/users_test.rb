require "application_system_test_case"

class UsersSystemTest < ApplicationSystemTestCase
  test "creating, editing, and deleting a user" do
    visit admin_users_path
    click_on "New user"

    fill_in "Name", with: "Robin"
    fill_in "Phone number", with: "+15555550150"
    click_on "Create User"

    assert_text "Robin"
    assert_text "+15555550150"

    click_on "Edit"
    fill_in "Name", with: "Robin Updated"
    click_on "Update User"

    assert_text "Robin Updated"

    visit admin_users_path
    accept_confirm do
      within first(".bg-white.border", text: "Robin Updated") do
        click_on "Delete"
      end
    end

    assert_no_text "Robin Updated"
  end

  test "sending a freeform message and a welcome message both show a friendly error without Twilio configured" do
    visit admin_user_path(users(:one))

    click_on "Send message"
    assert_text "Send a message to Alex"
    fill_in "Type a one-off message to send right now…", with: "Don't forget the trash!"
    click_on "Send"
    assert_text "Twilio is not configured"

    visit admin_user_path(users(:one))
    click_on "Send welcome message"
    assert_text "Twilio is not configured"
  end

  test "sending a blank freeform message is rejected before contacting Twilio" do
    visit admin_user_path(users(:one))

    click_on "Send message"
    click_on "Send"
    assert_text "Message can't be blank"
  end
end
