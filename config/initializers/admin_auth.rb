# Single shared password for the /admin area (see README/CLAUDE.md — this
# app has no per-user accounts). Required everywhere except test, which
# sets a fixed password itself in test/test_helper.rb so the suite doesn't
# depend on a developer's local .env (dotenv-rails is deliberately excluded
# from :test, see CLAUDE.md).
#
# require_relative rather than relying on Zeitwerk autoloading: the main
# autoloader isn't set up yet when config/initializers run (it happens later,
# in the finisher), so a bare constant reference here would raise.
require_relative "../../app/middleware/admin_session_gate"

Rails.application.config.middleware.use AdminSessionGate
