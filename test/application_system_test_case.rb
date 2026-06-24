require "test_helper"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800], js_errors: true)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite

  setup do
    visit login_path
    fill_in "Password", with: ENV.fetch("ADMIN_PASSWORD")
    click_button "Log in"
  end
end
