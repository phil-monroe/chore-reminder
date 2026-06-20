require "test_helper"

class User::SendWelcomeMessageTest < ActiveSupport::TestCase
  test "sends a canned onboarding message that includes the user's name" do
    user = users(:one)
    fake_sender = User::SendMessageTest::FakeSender.new

    User::SendWelcomeMessage.new(user: user, sender: fake_sender).call

    assert_equal 1, fake_sender.calls.size
    assert_equal user.phone_number, fake_sender.calls.first[:to]
    assert_includes fake_sender.calls.first[:body], user.name
  end

  test "includes the list of text commands a household member can send" do
    user = users(:one)
    fake_sender = User::SendMessageTest::FakeSender.new

    User::SendWelcomeMessage.new(user: user, sender: fake_sender).call

    assert_includes fake_sender.calls.first[:body], User::HandleInboundSms::HELP_TEXT
  end
end
