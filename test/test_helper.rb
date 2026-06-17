ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
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
