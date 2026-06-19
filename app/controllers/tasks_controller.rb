class TasksController < ApplicationController
  include ControllerWithUser

  before_action :set_task, only: %i[edit update destroy move_higher move_lower toggle_done]

  def index
    @tasks = @user.tasks.order(:position)
    render Views::Tasks::Index.new(user: @user, tasks: @tasks)
  end

  def new
    @task = @user.tasks.new
    render Views::Tasks::Form.new(user: @user, task: @task)
  end

  def edit
    render Views::Tasks::Form.new(user: @user, task: @task)
  end

  def create
    previous_next_task_id = Task.next_for(@user)&.id
    @task = @user.tasks.new(task_params)
    if @task.save
      notify_if_next_task_changed(previous_next_task_id)
      redirect_to user_tasks_path(@user), notice: "Task created."
    else
      render Views::Tasks::Form.new(user: @user, task: @task), status: :unprocessable_content
    end
  end

  def update
    previous_next_task_id = Task.next_for(@user)&.id
    if @task.update(task_params)
      notify_if_next_task_changed(previous_next_task_id)
      redirect_to user_tasks_path(@user), notice: "Task updated."
    else
      render Views::Tasks::Form.new(user: @user, task: @task), status: :unprocessable_content
    end
  end

  def destroy
    previous_next_task_id = Task.next_for(@user)&.id
    @task.destroy
    notify_if_next_task_changed(previous_next_task_id)
    redirect_to user_tasks_path(@user), notice: "Task deleted."
  end

  def move_higher
    previous_next_task_id = Task.next_for(@user)&.id
    @task.move_higher
    notify_if_next_task_changed(previous_next_task_id)
    respond_to_task_list_change
  end

  def move_lower
    previous_next_task_id = Task.next_for(@user)&.id
    @task.move_lower
    notify_if_next_task_changed(previous_next_task_id)
    respond_to_task_list_change
  end

  def toggle_done
    previous_next_task_id = Task.next_for(@user)&.id
    @task.update!(done: !@task.done)
    notify_if_next_task_changed(previous_next_task_id)

    # The dashboard's "Mark done" button lives inside a turbo frame scoped to
    # that user's next task, not the "tasks" list rendered by the tasks index
    # page — re-rendering the tasks list there wouldn't match anything on the
    # dashboard, so the page would silently fail to update.
    if turbo_frame_request_id == Views::Dashboard::NextTask.frame_id(@user)
      render Views::Dashboard::NextTask.new(user: @user)
    else
      respond_to_task_list_change
    end
  end

  private

  def notify_if_next_task_changed(previous_next_task_id)
    NotifyNextTaskChangedJob.perform_later(@user.id, previous_next_task_id)
  end

  def set_task
    @task = @user.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:name, :task_definition_id)
  end

  def respond_to_task_list_change
    @tasks = @user.tasks.order(:position)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("tasks", Views::Tasks::List.new(user: @user, tasks: @tasks)) }
      format.html { redirect_to user_tasks_path(@user) }
    end
  end
end
