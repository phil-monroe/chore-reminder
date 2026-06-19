require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "new_message page links back to the user" do
    user = users(:one)

    get new_message_user_path(user)

    assert_select "a[href='#{user_path(user)}']", text: /Back to #{user.name}/
  end

  test "send_message rejects a blank body without contacting Twilio and returns to the message page" do
    user = users(:one)

    post send_message_user_path(user), params: {body: "   "}

    assert_redirected_to new_message_user_path(user)
    follow_redirect!
    assert_match(/be blank/, response.body)
  end

  test "send_message shows a friendly error when Twilio is not configured and returns to the message page" do
    user = users(:one)

    post send_message_user_path(user), params: {body: "Don't forget the trash!"}

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

  test "conversation page lists messages and links back to the user" do
    user = users(:one)
    user.messages.create!(direction: :inbound, body: "DONE")
    user.messages.create!(direction: :outbound, body: "Marked \"Feed the pets\" done.")

    get conversation_user_path(user)

    assert_select "a[href='#{user_path(user)}']", text: /Back to #{user.name}/
    assert_match "DONE", response.body
    assert_match "Marked &quot;Feed the pets&quot; done.", response.body
  end

  test "conversation page renders a URL in a message body as a clickable link" do
    user = users(:one)
    user.messages.create!(direction: :outbound, body: "Feed the pets\nhttp://localhost:3000/users/1/task_definitions/1")

    get conversation_user_path(user)

    assert_select "a[href='http://localhost:3000/users/1/task_definitions/1'][target='_blank']",
      text: "http://localhost:3000/users/1/task_definitions/1"
  end

  test "send_inbound_message runs the DONE command, attempts to deliver the reply as a real text, and redirects to the conversation page" do
    user = users(:one)
    top = tasks(:one)

    post send_inbound_message_user_path(user), params: {body: "DONE"}

    assert_redirected_to conversation_user_path(user)
    assert top.reload.done
    # Test env has no real Twilio credentials configured, so the reply attempts a real
    # send and hits the same friendly "Twilio is not configured" failure as send_message
    # above — this confirms it's a genuine send attempt, not just a local log entry.
    follow_redirect!
    assert_match(/Twilio is not configured/, response.body)
    assert_equal ["DONE"], user.messages.order(:created_at).pluck(:body)
  end
end
