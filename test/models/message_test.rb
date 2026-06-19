require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "invalid without a body" do
    message = Message.new(user: users(:one), direction: :outbound, body: nil)
    assert_not message.valid?
  end

  test "invalid without a direction" do
    message = Message.new(user: users(:one), body: "Hello")
    assert_not message.valid?
  end

  test "direction is exposed as inbound/outbound predicates" do
    message = Message.new(user: users(:one), direction: :inbound, body: "DONE")
    assert message.inbound?
    assert_not message.outbound?
  end
end
