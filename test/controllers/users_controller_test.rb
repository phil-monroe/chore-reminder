require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "show page links back to the users list" do
    get user_path(users(:one))

    assert_select "a[href='#{users_path}']", text: /Back to users/
  end

  test "send_test_sms shows a friendly error when Twilio is not configured" do
    user = users(:one)

    post send_test_sms_user_path(user)

    assert_redirected_to user_path(user)
    follow_redirect!
    assert_match(/Twilio is not configured/, response.body)
  end
end
