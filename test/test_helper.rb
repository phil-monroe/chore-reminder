ENV["RAILS_ENV"] ||= "test"

# Fixed credentials for the site-wide Basic Auth middleware (config/initializers/basic_auth.rb).
# dotenv-rails is deliberately not loaded in :test (see CLAUDE.md), so these
# must be set explicitly rather than relying on a developer's local .env.
ENV["BASIC_AUTH_USERNAME"] ||= "test"
ENV["BASIC_AUTH_PASSWORD"] ||= "test"

# Fixed token for verifying the Twilio inbound SMS webhook's request
# signature (Integrations::TwilioController). Same dotenv rationale as
# above: must not depend on whatever happens to be in a developer's .env.
ENV["TWILIO_AUTH_TOKEN"] ||= "test-twilio-auth-token"

require_relative "../config/environment"
require "rails/test_help"

# Every integration test request needs valid Basic Auth credentials now that
# the whole site is gated. Inject them automatically so individual tests
# don't each have to set the header themselves. Prepended (not reopened)
# because Session#process is defined directly on the class itself — reopening
# it would replace the original method body rather than wrap it, leaving
# `super` with nothing to call.
module InjectsBasicAuthHeader
  def process(method, path, **args)
    args[:headers] ||= {}
    args[:headers]["Authorization"] ||=
      ActionController::HttpAuthentication::Basic.encode_credentials(
        ENV.fetch("BASIC_AUTH_USERNAME"), ENV.fetch("BASIC_AUTH_PASSWORD")
      )
    super
  end
end
ActionDispatch::Integration::Session.prepend(InjectsBasicAuthHeader)

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
