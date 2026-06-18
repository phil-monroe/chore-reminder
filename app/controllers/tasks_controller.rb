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
    @task = @user.tasks.new(task_params)
    if @task.save
      redirect_to user_tasks_path(@user), notice: "Task created."
    else
      render Views::Tasks::Form.new(user: @user, task: @task), status: :unprocessable_content
    end
  end

  def update
    if @task.update(task_params)
      redirect_to user_tasks_path(@user), notice: "Task updated."
    else
      render Views::Tasks::Form.new(user: @user, task: @task), status: :unprocessable_content
    end
  end

  def destroy
    @task.destroy
    redirect_to user_tasks_path(@user), notice: "Task deleted."
  end

  def move_higher
    @task.move_higher
    respond_to_task_list_change
  end

  def move_lower
    @task.move_lower
    respond_to_task_list_change
  end

  def toggle_done
    @task.update!(done: !@task.done)
    respond_to_task_list_change
  end

  private

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
