require "application_system_test_case"

class UsersSystemTest < ApplicationSystemTestCase
  test "creating, editing, and deleting a user" do
    visit users_path
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

    visit users_path
    accept_confirm do
      within first(".bg-white.border", text: "Robin Updated") do
        click_on "Delete"
      end
    end

    assert_no_text "Robin Updated"
  end
end
