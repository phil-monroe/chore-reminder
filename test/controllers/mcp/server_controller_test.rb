require "test_helper"

class Mcp::ServerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @client = oauth_clients(:one)
    @user = users(:one)
    @access_token = Oauth::SignedTokens.generate_access_token(client_id: @client.client_id, user: @user)
  end

  def post_mcp(body, token: @access_token)
    headers = {"Content-Type" => "application/json"}
    headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: body.to_json, headers: headers
  end

  def rpc_result(body)
    post_mcp(body)
    JSON.parse(response.body)["result"]
  end

  test "POST /mcp with no Authorization header is rejected with a resource_metadata challenge and no error param" do
    post_mcp({jsonrpc: "2.0", id: 1, method: "tools/list"}, token: nil)

    assert_response :unauthorized
    assert_match %r{resource_metadata="#{Regexp.escape(oauth_protected_resource_metadata_url)}"}, response.headers["WWW-Authenticate"]
    assert_no_match(/error=/, response.headers["WWW-Authenticate"])
  end

  test "POST /mcp with a token whose client was revoked is rejected with an invalid_token challenge" do
    @client.destroy

    post_mcp({jsonrpc: "2.0", id: 1, method: "tools/list"})

    assert_response :unauthorized
    assert_match(/error="invalid_token"/, response.headers["WWW-Authenticate"])
  end

  test "POST /mcp with a tampered token is rejected" do
    post_mcp({jsonrpc: "2.0", id: 1, method: "tools/list"}, token: "#{@access_token}tampered")

    assert_response :unauthorized
    assert_match(/error="invalid_token"/, response.headers["WWW-Authenticate"])
  end

  test "POST /mcp with a token bound to a different resource is rejected" do
    token = Oauth::SignedTokens.generate_access_token(client_id: @client.client_id, user: @user, resource: "https://not-this-server.example.com/mcp")

    post_mcp({jsonrpc: "2.0", id: 1, method: "tools/list"}, token: token)

    assert_response :unauthorized
  end

  test "POST /mcp with a token bound to this server's resource succeeds" do
    token = Oauth::SignedTokens.generate_access_token(client_id: @client.client_id, user: @user, resource: mcp_url)

    post_mcp({jsonrpc: "2.0", id: 1, method: "tools/list"}, token: token)

    assert_response :success
  end

  test "tools/list returns all 13 registered tools" do
    result = rpc_result({jsonrpc: "2.0", id: 1, method: "tools/list"})

    assert_equal Mcp::ToolRegistry.all.size, result["tools"].size
    assert_includes result["tools"].pluck("name"), "list_users"
  end

  test "tools/call list_users returns every household member" do
    result = rpc_result({jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "list_users", arguments: {}}})

    names = JSON.parse(result["content"].first["text"]).pluck("name")
    assert_equal User.pluck(:name).sort, names.sort
  end

  test "tools/call list_tasks with no user_id defaults to the token's user" do
    result = rpc_result({jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "list_tasks", arguments: {}}})

    task_names = JSON.parse(result["content"].first["text"]).pluck("name")
    assert_equal @user.tasks.pending.pluck(:name), task_names
  end

  test "tools/call list_tasks with an explicit user_id acts on that user instead" do
    other_user = users(:two)

    result = rpc_result({jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "list_tasks", arguments: {user_id: other_user.id.to_s}}})

    task_names = JSON.parse(result["content"].first["text"]).pluck("name")
    assert_equal other_user.tasks.pending.pluck(:name), task_names
  end

  test "tools/call toggle_task marks the task done and enqueues the next-task notification" do
    task = tasks(:one)

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [@user.id, task.id]) do
      rpc_result({jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "toggle_task", arguments: {task_id: task.id}}})
    end

    assert task.reload.done?
  end

  test "tools/call create_task_definition creates a new task definition for the token's user" do
    assert_difference -> { @user.task_definitions.count }, 1 do
      result = rpc_result({
        jsonrpc: "2.0", id: 1, method: "tools/call",
        params: {name: "create_task_definition", arguments: {name: "Water plants", time_of_day: "09:00"}}
      })

      assert_not result["isError"]
    end
  end

  test "tools/call with missing required arguments returns a tool error" do
    result = rpc_result({jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "toggle_task", arguments: {}}})

    assert result["isError"]
  end
end
