require "test_helper"

class Public::TaskDefinitionsControllerTest < ActionDispatch::IntegrationTest
  test "shows the task definition's name and rendered description" do
    td = task_definitions(:one)

    get public_task_definition_path(username: td.user.to_param, task_definition_slug: td.to_param)

    assert_response :success
    assert_select "h1", text: td.name
    assert_match "<strong>both</strong>", response.body
  end

  test "is reachable with no Basic Auth credentials at all" do
    td = task_definitions(:one)

    get public_task_definition_path(username: td.user.to_param, task_definition_slug: td.to_param),
      headers: {"Authorization" => ""}

    assert_response :success
  end

  test "works via the user's username and the task_definition's slug once set" do
    td = task_definitions(:one)
    td.user.update!(username: "alex")
    td.update!(slug: "feed-the-pets")

    get "/alex/feed-the-pets", headers: {"Authorization" => ""}

    assert_response :success
    assert_select "h1", text: td.name
  end

  test "404s for an unknown username" do
    td = task_definitions(:one)

    get public_task_definition_path(username: "nope", task_definition_slug: td.to_param)

    assert_response :not_found
  end

  test "404s for an unknown task_definition_slug" do
    td = task_definitions(:one)

    get public_task_definition_path(username: td.user.to_param, task_definition_slug: "nope")

    assert_response :not_found
  end

  test "404s for another user's task_definition id" do
    other = task_definitions(:two)

    get public_task_definition_path(username: users(:one).to_param, task_definition_slug: other.to_param)

    assert_response :not_found
  end
end
