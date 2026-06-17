module Sms
  class TwilioSender
    def initialize(client: Twilio::REST::Client.new(ENV.fetch("TWILIO_ACCOUNT_SID"), ENV.fetch("TWILIO_AUTH_TOKEN")))
      @client = client
    end

    def send(to:, body:)
      @client.messages.create(from: ENV.fetch("TWILIO_FROM_NUMBER"), to: to, body: body)
    end
  end
end
