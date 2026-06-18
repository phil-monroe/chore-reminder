# Single shared username/password for the whole site (see README/CLAUDE.md —
# this app has no per-user accounts). Required everywhere except test, which
# sets fixed credentials itself in test/test_helper.rb so the suite doesn't
# depend on a developer's local .env (dotenv-rails is deliberately excluded
# from :test, see CLAUDE.md).
#
# require_relative rather than relying on Zeitwerk autoloading: app/middleware
# isn't an autoload root by default, and this needs to be loadable at
# middleware-stack-build time, before the app's normal autoloading is set up.
require_relative "../../app/middleware/basic_auth_skip_health_check"

Rails.application.config.middleware.use BasicAuthSkipHealthCheck, "Chore Reminder" do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(username, ENV.fetch("BASIC_AUTH_USERNAME")) &
    ActiveSupport::SecurityUtils.secure_compare(password, ENV.fetch("BASIC_AUTH_PASSWORD"))
end
