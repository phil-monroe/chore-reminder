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

  test "creating the first task enqueues a next-task notification" do
    user = users(:one)
    user.tasks.destroy_all

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [user.id, nil]) do
      post user_tasks_path(user), params: {task: {name: "New task"}}
    end
  end

  test "destroying the top task enqueues a next-task notification" do
    task = tasks(:one)

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [task.user_id, task.id]) do
      delete user_task_path(task.user, task)
    end
  end

  test "marking the top task done enqueues a next-task notification" do
    task = tasks(:one)

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [task.user_id, task.id]) do
      patch toggle_done_user_task_path(task.user, task)
    end
  end

  test "renaming a task (which can't change what's next) still enqueues the job, harmlessly" do
    task = tasks(:one)

    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [task.user_id, task.id]) do
      patch user_task_path(task.user, task), params: {task: {name: "Renamed"}}
    end
  end
end
