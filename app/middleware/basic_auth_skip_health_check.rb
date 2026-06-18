# Wraps the whole site (including the mounted GoodJob dashboard, which has
# its own controllers outside ApplicationController) in one shared HTTP Basic
# Auth gate. Skips the Rails health check path so uptime monitors don't need
# credentials.
class BasicAuthSkipHealthCheck < Rack::Auth::Basic
  def call(env)
    return @app.call(env) if env["PATH_INFO"] == "/up"
    super
  end
end
