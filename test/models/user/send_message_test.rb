require "test_helper"

class User::SendMessageTest < ActiveSupport::TestCase
  class FakeSender
    attr_reader :calls

    def initialize
      @calls = []
    end

    def send(to:, body:)
      @calls << {to: to, body: body}
    end
  end

  test "sends the given body to the user's phone number" do
    user = users(:one)
    fake_sender = FakeSender.new

    User::SendMessage.new(user: user, body: "Don't forget the trash!", sender: fake_sender).call

    assert_equal 1, fake_sender.calls.size
    assert_equal user.phone_number, fake_sender.calls.first[:to]
    assert_equal "Don't forget the trash!", fake_sender.calls.first[:body]
  end

  test "strips whitespace from the body before sending" do
    user = users(:one)
    fake_sender = FakeSender.new

    User::SendMessage.new(user: user, body: "  Hello  ", sender: fake_sender).call

    assert_equal "Hello", fake_sender.calls.first[:body]
  end

  test "raises BlankBodyError without contacting the sender when the body is blank" do
    user = users(:one)
    fake_sender = FakeSender.new

    assert_raises(User::SendMessage::BlankBodyError) do
      User::SendMessage.new(user: user, body: "   ", sender: fake_sender).call
    end

    assert_empty fake_sender.calls
  end
end
