require "test_helper"

module Sms
  class TwilioSenderTest < ActiveSupport::TestCase
    class FakeMessages
      attr_reader :created_with

      def create(**kwargs)
        @created_with = kwargs
      end
    end

    class FakeClient
      def messages
        @messages ||= FakeMessages.new
      end
    end

    test "sends via the injected client with from/to/body" do
      ENV["TWILIO_FROM_NUMBER"] = "+15555550100"
      client = FakeClient.new
      sender = TwilioSender.new(client: client)

      sender.send(to: "+12025550199", body: "Hello")

      assert_equal({from: "+15555550100", to: "+12025550199", body: "Hello"}, client.messages.created_with)
    ensure
      ENV.delete("TWILIO_FROM_NUMBER")
    end

    test "propagates errors raised by the client" do
      client = FakeClient.new
      def client.messages
        raise Twilio::REST::RestError.new("boom", Twilio::Response.new(500, "{}"))
      end
      sender = TwilioSender.new(client: client)

      assert_raises(Twilio::REST::RestError) { sender.send(to: "+12025550199", body: "Hello") }
    end

    test "skips sending to a fictional +1555 number without contacting the client" do
      client = FakeClient.new
      def client.messages
        raise "the client should never be reached for a fictional number"
      end
      sender = TwilioSender.new(client: client)

      assert_nil sender.send(to: "+15555550199", body: "Hello")
    end
  end
end
