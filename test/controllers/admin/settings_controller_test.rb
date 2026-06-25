require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/settings links to connected apps" do
    get admin_settings_path

    assert_response :success
    assert_includes response.body, "Connected apps"
  end
end
