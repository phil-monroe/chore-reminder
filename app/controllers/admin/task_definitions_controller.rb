class Admin::TaskDefinitionsController < ApplicationController
  include ControllerWithUser

  before_action :set_task_definition, only: %i[show edit update destroy generate_now]

  def index
    @task_definitions = @user.task_definitions
    render Views::Admin::TaskDefinitions::Index.new(user: @user, task_definitions: @task_definitions)
  end

  def show
    render Views::Admin::TaskDefinitions::Show.new(user: @user, task_definition: @task_definition)
  end

  def new
    @task_definition = @user.task_definitions.new
    render Views::Admin::TaskDefinitions::Form.new(user: @user, task_definition: @task_definition)
  end

  def edit
    render Views::Admin::TaskDefinitions::Form.new(user: @user, task_definition: @task_definition)
  end

  def create
    @task_definition = @user.task_definitions.new(task_definition_params)
    if @task_definition.save
      redirect_to admin_user_task_definition_path(@user, @task_definition), notice: "Task definition created."
    else
      render Views::Admin::TaskDefinitions::Form.new(user: @user, task_definition: @task_definition), status: :unprocessable_content
    end
  end

  def update
    if @task_definition.update(task_definition_params)
      redirect_to admin_user_task_definition_path(@user, @task_definition), notice: "Task definition updated."
    else
      render Views::Admin::TaskDefinitions::Form.new(user: @user, task_definition: @task_definition), status: :unprocessable_content
    end
  end

  def destroy
    @task_definition.destroy
    redirect_to admin_user_task_definitions_path(@user), notice: "Task definition deleted."
  end

  def generate_now
    TaskDefinition::GenerateForToday.new(task_definition: @task_definition).call
    redirect_to admin_user_task_definition_path(@user, @task_definition), notice: "Today's task generated (if not already created)."
  end

  private

  def set_task_definition
    @task_definition = @user.task_definitions.find_by_param!(params[:id])
  end

  def task_definition_params
    params.require(:task_definition).permit(:name, :description, :time_of_day, recurrence_days: [], images: [])
  end
end
