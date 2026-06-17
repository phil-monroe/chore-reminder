require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  test "index page links back to the user" do
    user = users(:one)

    get user_tasks_path(user)

    assert_select "a[href='#{user_path(user)}']", text: /Back to #{user.name}/
  end
end
