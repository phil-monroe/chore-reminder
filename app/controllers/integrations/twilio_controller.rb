# Twilio posts here without our shared Basic Auth credentials (see
# config/initializers/basic_auth.rb / app/middleware/basic_auth_admin_gate.rb,
# which only gates the /admin namespace) and without a Rails CSRF token, so
# this controller authenticates the request itself via Twilio's request
# signature instead.
class Integrations::TwilioController < ApplicationController
  skip_forgery_protection

  before_action :validate_twilio_signature!

  def sms_inbound_webhook
    user = User.find_by(phone_number: params["From"])

    reply = if user
      User::HandleInboundSms.new(user: user, body: params["Body"]).call
    else
      "We don't recognize this number."
    end

    render xml: twiml(reply)
  end

  private

  def twiml(message)
    Twilio::TwiML::MessagingResponse.new.tap { |response| response.message(body: message) }.to_s
  end

  # Twilio signs every webhook request with the account's auth token so we
  # can be sure it actually came from Twilio (anyone can guess this URL).
  # request.request_parameters (not `params`) is used deliberately: it's the
  # raw posted body only, excluding the route/format params Rails adds to
  # `params`, which must match exactly what Twilio signed.
  def validate_twilio_signature!
    validator = Twilio::Security::RequestValidator.new(ENV.fetch("TWILIO_AUTH_TOKEN"))
    signature = request.headers["X-Twilio-Signature"].to_s

    return if validator.validate(request.original_url, request.request_parameters, signature)

    head :forbidden
  end
end
