require "test_helper"

class Admin::TasksControllerTest < ActionDispatch::IntegrationTest
  test "index page links back to the user" do
    user = users(:one)

    get admin_user_tasks_path(user)

    assert_select "a[href='#{admin_user_path(user)}']", text: /Back to #{user.name}/
  end

  test "index page lists only pending tasks and links to a filtered completed-tasks page" do
    user = users(:one)
    user.tasks.destroy_all
    pending = user.tasks.create!(name: "Pending task")
    completed = user.tasks.create!(name: "Completed task", done: true)

    get admin_user_tasks_path(user)

    assert_select "#tasks", text: /#{pending.name}/
    assert_no_match(/#{completed.name}/, response.body)
    assert_select "a[href='#{admin_user_tasks_path(user, done: true)}']", text: "Show completed tasks"
  end

  test "index page with done=true lists only completed tasks and links back to pending" do
    user = users(:one)
    user.tasks.destroy_all
    pending = user.tasks.create!(name: "Pending task")
    completed = user.tasks.create!(name: "Completed task", done: true)

    get admin_user_tasks_path(user, done: true)

    assert_select "#tasks", text: /#{completed.name}/
    assert_no_match(/#{pending.name}/, response.body)
    assert_select "a[href='#{admin_user_tasks_path(user)}']", text: "← Back to pending tasks"
  end

  test "new form's cancel button links to the task list" do
    user = users(:one)

    get new_admin_user_task_path(user)

    assert_select "a[href='#{admin_user_tasks_path(user)}']", text: "Cancel"
  end

  test "edit form's cancel button links to the task list" do
    task = tasks(:one)

    get edit_admin_user_task_path(task.user, task)

    assert_select "a[href='#{admin_user_tasks_path(task.user)}']", text: "Cancel"
  end

  test "creating the first task enqueues a next-task notification" do
    user = users(:one)
    user.tasks.destroy_all

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [user.id, nil]) do
      post admin_user_tasks_path(user), params: {task: {name: "New task"}}
    end
  end

  test "destroying the top task enqueues a next-task notification" do
    task = tasks(:one)

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [task.user_id, task.id]) do
      delete admin_user_task_path(task.user, task)
    end
  end

  test "marking the top task done enqueues a next-task notification" do
    task = tasks(:one)

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [task.user_id, task.id]) do
      patch toggle_done_admin_user_task_path(task.user, task)
    end
  end

  test "renaming a task (which can't change what's next) still enqueues the job, harmlessly" do
    task = tasks(:one)

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [task.user_id, task.id]) do
      patch admin_user_task_path(task.user, task), params: {task: {name: "Renamed"}}
    end
  end
end
