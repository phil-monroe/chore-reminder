require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "new_message page links back to the user" do
    user = users(:one)

    get new_message_user_path(user)

    assert_select "a[href='#{user_path(user)}']", text: /Back to #{user.name}/
  end

  test "send_message rejects a blank body without contacting Twilio and returns to the message page" do
    user = users(:one)

    post send_message_user_path(user), params: { body: "   " }

    assert_redirected_to new_message_user_path(user)
    follow_redirect!
    assert_match(/be blank/, response.body)
  end

  test "send_message shows a friendly error when Twilio is not configured and returns to the message page" do
    user = users(:one)

    post send_message_user_path(user), params: { body: "Don't forget the trash!" }

    assert_redirected_to new_message_user_path(user)
    follow_redirect!
    assert_match(/Twilio is not configured/, response.body)
  end

  test "send_welcome_message shows a friendly error when Twilio is not configured" do
    user = users(:one)

    post send_welcome_message_user_path(user)

    assert_redirected_to user_path(user)
    follow_redirect!
    assert_match(/Twilio is not configured/, response.body)
  end

  test "show page links back to the users list" do
    get user_path(users(:one))

    assert_select "a[href='#{users_path}']", text: /Back to users/
  end

  test "new form's cancel button links to the users list" do
    get new_user_path

    assert_select "a[href='#{users_path}']", text: "Cancel"
  end

  test "edit form's cancel button links to the user's show page" do
    user = users(:one)

    get edit_user_path(user)

    assert_select "a[href='#{user_path(user)}']", text: "Cancel"
  end
end
