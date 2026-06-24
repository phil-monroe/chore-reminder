require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /login redirects to the admin dashboard when already logged in" do
    get login_path

    assert_redirected_to admin_root_path
  end

  test "GET /login renders the login form when not logged in" do
    delete logout_path

    get login_path

    assert_response :success
  end

  test "POST /login with the correct password logs in and redirects to the admin dashboard" do
    delete logout_path

    post login_path, params: {password: ENV.fetch("ADMIN_PASSWORD")}

    assert_redirected_to admin_root_path
  end

  test "POST /login with an incorrect password re-renders the form" do
    delete logout_path

    post login_path, params: {password: "wrong"}

    assert_response :unprocessable_content
  end

  test "DELETE /logout clears the session and redirects to the root page" do
    delete logout_path

    assert_redirected_to root_path
  end
end
