class TaskDefinitionsController < ApplicationController
  include ControllerWithUser

  before_action :set_task_definition, only: %i[show edit update destroy generate_now]

  def index
    @task_definitions = @user.task_definitions
    render Views::TaskDefinitions::Index.new(user: @user, task_definitions: @task_definitions)
  end

  def show
    render Views::TaskDefinitions::Show.new(user: @user, task_definition: @task_definition)
  end

  def new
    @task_definition = @user.task_definitions.new
    render Views::TaskDefinitions::Form.new(user: @user, task_definition: @task_definition)
  end

  def edit
    render Views::TaskDefinitions::Form.new(user: @user, task_definition: @task_definition)
  end

  def create
    @task_definition = @user.task_definitions.new(task_definition_params)
    if @task_definition.save
      redirect_to user_task_definition_path(@user, @task_definition), notice: "Task definition created."
    else
      render Views::TaskDefinitions::Form.new(user: @user, task_definition: @task_definition), status: :unprocessable_content
    end
  end

  def update
    if @task_definition.update(task_definition_params)
      redirect_to user_task_definition_path(@user, @task_definition), notice: "Task definition updated."
    else
      render Views::TaskDefinitions::Form.new(user: @user, task_definition: @task_definition), status: :unprocessable_content
    end
  end

  def destroy
    @task_definition.destroy
    redirect_to user_task_definitions_path(@user), notice: "Task definition deleted."
  end

  def generate_now
    @task_definition.generate_task_for_today!
    redirect_to user_task_definition_path(@user, @task_definition), notice: "Today's task generated (if not already created)."
  end

  private

  def set_task_definition
    @task_definition = @user.task_definitions.find(params[:id])
  end

  def task_definition_params
    params.require(:task_definition).permit(:name, :description, recurrence_days: [], images: [])
  end
end
