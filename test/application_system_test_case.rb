require "test_helper"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800], js_errors: true)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite

  setup do
    page.driver.basic_authorize(ENV.fetch("BASIC_AUTH_USERNAME"), ENV.fetch("BASIC_AUTH_PASSWORD"))
  end
end
