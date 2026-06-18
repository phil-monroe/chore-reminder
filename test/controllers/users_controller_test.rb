require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  class FakeSender
    attr_reader :calls

    def initialize
      @calls = []
    end

    def send(to:, body:)
      @calls << { to: to, body: body }
    end
  end

  def with_sender(sender)
    original = UsersController.sms_sender_factory
    UsersController.sms_sender_factory = -> { sender }
    yield
  ensure
    UsersController.sms_sender_factory = original
  end

  test "send_message sends the given body to the user's phone number" do
    user = users(:one)
    fake_sender = FakeSender.new

    with_sender(fake_sender) do
      post send_message_user_path(user), params: { body: "Don't forget the trash!" }
    end

    assert_redirected_to user_path(user)
    assert_equal 1, fake_sender.calls.size
    assert_equal user.phone_number, fake_sender.calls.first[:to]
    assert_equal "Don't forget the trash!", fake_sender.calls.first[:body]
  end

  test "send_message rejects a blank body without contacting Twilio" do
    user = users(:one)
    fake_sender = FakeSender.new

    with_sender(fake_sender) do
      post send_message_user_path(user), params: { body: "   " }
    end

    assert_redirected_to user_path(user)
    follow_redirect!
    assert_match(/be blank/, response.body)
    assert_empty fake_sender.calls
  end

  test "send_welcome_message sends the canned onboarding message" do
    user = users(:one)
    fake_sender = FakeSender.new

    with_sender(fake_sender) do
      post send_welcome_message_user_path(user)
    end

    assert_redirected_to user_path(user)
    assert_equal 1, fake_sender.calls.size
    assert_equal user.phone_number, fake_sender.calls.first[:to]
    assert_equal user.welcome_message_body, fake_sender.calls.first[:body]
    assert_includes fake_sender.calls.first[:body], user.name
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

  test "send_test_sms shows a friendly error when Twilio is not configured" do
    user = users(:one)

    post send_test_sms_user_path(user)

    assert_redirected_to user_path(user)
    follow_redirect!
    assert_match(/Twilio is not configured/, response.body)
  end
end
