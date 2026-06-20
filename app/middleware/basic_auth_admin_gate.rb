# Gates only the /admin namespace behind one shared HTTP Basic Auth
# credential pair (see CLAUDE.md - this app has no per-user accounts). The
# mounted GoodJob dashboard lives under /admin/good_job (config/routes.rb)
# so it's covered by this same prefix check, despite having its own
# controllers outside ApplicationController.
#
# Everything else - the Rails health check, the Twilio inbound SMS webhook
# (which Twilio can't supply these credentials for and authenticates itself
# via its own request signature instead, see Integrations::TwilioController),
# and the public per-task page linked from reminder texts
# (Public::TaskDefinitionsController) - is reachable with no credentials at
# all, so a simple path-prefix check is enough; there's no need to enumerate
# what's excluded.
class BasicAuthAdminGate < Rack::Auth::Basic
  ADMIN_PATH_PREFIX = "/admin"

  def call(env)
    return @app.call(env) unless env["PATH_INFO"].start_with?(ADMIN_PATH_PREFIX)
    super
  end
end
