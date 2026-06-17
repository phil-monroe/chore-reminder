require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  test "index page links back to the user" do
    user = users(:one)

    get user_tasks_path(user)

    assert_select "a[href='#{user_path(user)}']", text: /Back to #{user.name}/
  end

  test "new form's cancel button links to the task list" do
    user = users(:one)

    get new_user_task_path(user)

    assert_select "a[href='#{user_tasks_path(user)}']", text: "Cancel"
  end

  test "edit form's cancel button links to the task list" do
    task = tasks(:one)

    get edit_user_task_path(task.user, task)

    assert_select "a[href='#{user_tasks_path(task.user)}']", text: "Cancel"
  end
end
