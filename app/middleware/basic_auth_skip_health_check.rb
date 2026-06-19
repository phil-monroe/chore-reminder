# Wraps the whole site (including the mounted GoodJob dashboard, which has
# its own controllers outside ApplicationController) in one shared HTTP Basic
# Auth gate. Skips the Rails health check path so uptime monitors don't need
# credentials, and the Twilio inbound SMS webhook, which Twilio can't supply
# these credentials for and which authenticates itself via Twilio's request
# signature instead (see Integrations::TwilioController).
class BasicAuthSkipHealthCheck < Rack::Auth::Basic
  SKIPPED_PATHS = ["/up", "/integrations/twilio/sms_inbound_webhook"].freeze

  def call(env)
    return @app.call(env) if SKIPPED_PATHS.include?(env["PATH_INFO"])
    super
  end
end
