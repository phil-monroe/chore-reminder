require "test_helper"

class Admin::OauthClientsControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/oauth_clients lists registered clients" do
    get admin_oauth_clients_path

    assert_response :success
    assert_includes response.body, oauth_clients(:one).client_name
  end

  test "DELETE /admin/oauth_clients/:id revokes a client" do
    client = oauth_clients(:one)

    assert_difference -> { Oauth::Client.count }, -1 do
      delete admin_oauth_client_path(client)
    end

    assert_redirected_to admin_oauth_clients_path
  end
end
