module Sms
  class TwilioSender
    # NANP reserves the 555 line-number range (and, by convention in
    # examples/fixtures, the 555 area code) for fictional use — e.g. the
    # seed data in db/seeds.rb. Never actually deliver to one of these,
    # even if real Twilio credentials are configured.
    FICTIONAL_NUMBER = /\A\+1555/

    def initialize(client: Twilio::REST::Client.new(ENV.fetch("TWILIO_ACCOUNT_SID"), ENV.fetch("TWILIO_AUTH_TOKEN")))
      @client = client
    end

    def send(to:, body:)
      if to.to_s.match?(FICTIONAL_NUMBER)
        Rails.logger.info("Sms::TwilioSender: skipping send to fictional number #{to}")
        return
      end

      @client.messages.create(from: ENV.fetch("TWILIO_FROM_NUMBER"), to: to, body: body)
    end
  end
end
