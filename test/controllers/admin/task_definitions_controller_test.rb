require "test_helper"

class Admin::TaskDefinitionsControllerTest < ActionDispatch::IntegrationTest
  test "index page links back to the user" do
    user = users(:one)

    get admin_user_task_definitions_path(user)

    assert_select "a[href='#{admin_user_path(user)}']", text: /Back to #{user.name}/
  end

  test "show page links back to the task definitions list" do
    td = task_definitions(:one)

    get admin_user_task_definition_path(td.user, td)

    assert_select "a[href='#{admin_user_task_definitions_path(td.user)}']", text: /Back to task definitions/
  end

  test "show page links to the public page for the task definition" do
    td = task_definitions(:one)

    get admin_user_task_definition_path(td.user, td)

    assert_select "a[href='#{public_task_definition_path(username: td.user.to_param, task_definition_slug: td.to_param)}']",
      text: "View public page"
  end

  test "a task definition with a slug is reachable at /task_definitions/:slug instead of /:id" do
    td = task_definitions(:one)
    td.update!(slug: "feed-the-pets")

    assert_equal "/admin/users/#{td.user.to_param}/task_definitions/feed-the-pets", admin_user_task_definition_path(td.user, td)

    get admin_user_task_definition_path(td.user, td)

    assert_response :success
  end

  test "new form's cancel button links to the task definitions list" do
    user = users(:one)

    get new_admin_user_task_definition_path(user)

    assert_select "a[href='#{admin_user_task_definitions_path(user)}']", text: "Cancel"
  end

  test "edit form's cancel button links to the task definition's show page" do
    td = task_definitions(:one)

    get edit_admin_user_task_definition_path(td.user, td)

    assert_select "a[href='#{admin_user_task_definition_path(td.user, td)}']", text: "Cancel"
  end

  test "generate_now creates today's task when the definition recurs today" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [Date.current.wday])
    td.tasks.destroy_all

    assert_difference -> { td.tasks.count }, 1 do
      post generate_now_admin_user_task_definition_path(td.user, td)
    end

    assert_redirected_to admin_user_task_definition_path(td.user, td)
  end

  test "generate_now is a no-op when the definition does not recur today" do
    td = task_definitions(:one)
    td.update!(recurrence_days: [(Date.current.wday + 1) % 7])
    td.tasks.destroy_all

    assert_no_difference -> { td.tasks.count } do
      post generate_now_admin_user_task_definition_path(td.user, td)
    end
  end
end
