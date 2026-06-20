# Wraps the whole site (including the mounted GoodJob dashboard, which has
# its own controllers outside ApplicationController) in one shared HTTP Basic
# Auth gate. Skips the Rails health check path so uptime monitors don't need
# credentials, the Twilio inbound SMS webhook, which Twilio can't supply
# these credentials for and which authenticates itself via Twilio's request
# signature instead (see Integrations::TwilioController), and the public
# task definition page linked from reminder texts (see
# Public::TaskDefinitionsController), which household members open with no
# credentials at all.
class BasicAuthSkipHealthCheck < Rack::Auth::Basic
  SKIPPED_PATHS = ["/up", "/integrations/twilio/sms_inbound_webhook"].freeze
  SKIPPED_CONTROLLER_ACTIONS = [["public/task_definitions", "show"]].freeze

  def call(env)
    return @app.call(env) if SKIPPED_PATHS.include?(env["PATH_INFO"]) || skipped_route?(env)
    super
  end

  private

  # Matched by controller/action rather than a literal path, since the
  # public task definition page's path is two arbitrary, dynamic segments
  # (/:username/:task_definition_slug) - there's no fixed string to put in
  # SKIPPED_PATHS.
  def skipped_route?(env)
    route = Rails.application.routes.recognize_path(env["PATH_INFO"], method: env["REQUEST_METHOD"])
    SKIPPED_CONTROLLER_ACTIONS.include?([route[:controller], route[:action]])
  rescue ActionController::RoutingError
    false
  end
end
