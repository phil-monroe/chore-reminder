# Gates only the /admin namespace behind a signed-in session (see CLAUDE.md
# - this app has no per-user accounts, just one shared password). The
# mounted GoodJob dashboard lives under /admin/good_job (config/routes.rb)
# so it's covered by this same prefix check, despite having its own
# controllers outside ApplicationController.
#
# Everything else - the Rails health check, the Twilio inbound SMS webhook
# (which authenticates itself via its own request signature instead, see
# Integrations::TwilioController), the login page itself, and the public
# per-task page linked from reminder texts
# (Public::TaskDefinitionsController) - is reachable with no credentials at
# all, so a simple path-prefix check is enough; there's no need to enumerate
# what's excluded.
#
# Runs as a Rack middleware (rather than an ApplicationController
# before_action) for the same reason the old Basic Auth gate did: it has to
# see every request regardless of which Rails app/engine handles it, and
# GoodJob's mounted engine controllers don't inherit from
# ApplicationController. It's appended after ActionDispatch::Session::CookieStore
# in the middleware stack (config.middleware.use always appends), so
# env["rack.session"] is already populated by the time #call runs.
class AdminSessionGate
  ADMIN_PATH_PREFIX = "/admin"
  SESSION_KEY = :admin_authenticated

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    return @app.call(env) unless request.path.start_with?(ADMIN_PATH_PREFIX)
    return @app.call(env) if request.session[SESSION_KEY]

    [302, {"Location" => "/login"}, []]
  end
end
