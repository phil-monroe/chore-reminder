ENV["RAILS_ENV"] ||= "test"

# Fixed password for the admin area (Admin::BaseController#require_authenticated!,
# config/routes.rb's AdminSessionConstraint). dotenv-rails is deliberately
# not loaded in :test (see CLAUDE.md), so this must be set explicitly rather
# than relying on a developer's local .env.
ENV["ADMIN_PASSWORD"] ||= "test"

# Fixed token for verifying the Twilio inbound SMS webhook's request
# signature (Integrations::TwilioController). Same dotenv rationale as
# above: must not depend on whatever happens to be in a developer's .env.
ENV["TWILIO_AUTH_TOKEN"] ||= "test-twilio-auth-token"

require_relative "../config/environment"
require "rails/test_help"

# Every integration test request needs an authenticated session now that
# the whole admin area is gated. Logging in once per test (rather than
# requiring every test to do it) keeps existing controller tests from each
# needing their own login call. Prepended (not reopened) because
# Session#process is defined directly on the class itself — reopening it
# would replace the original method body rather than wrap it, leaving
# `super` with nothing to call.
module LogsInBeforeFirstRequest
  def process(method, path, **args)
    unless @logged_in_for_test
      @logged_in_for_test = true
      post "/login", params: {password: ENV.fetch("ADMIN_PASSWORD")}
    end
    super
  end
end
ActionDispatch::Integration::Session.prepend(LogsInBeforeFirstRequest)

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    # Parallel workers each spin up their own headless Chrome for system
    # tests; running several concurrently crashes the browser process and
    # hangs the suite (waiting forever on DRb). The suite is small enough
    # that parallelization isn't worth that instability.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
