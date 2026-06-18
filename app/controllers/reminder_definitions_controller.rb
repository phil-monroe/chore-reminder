class ReminderDefinitionsController < ApplicationController
  before_action :set_user
  before_action :set_reminder_definition, only: %i[show edit update destroy send_now]

  def index
    @reminder_definitions = @user.reminder_definitions
    render Views::ReminderDefinitions::Index.new(user: @user, reminder_definitions: @reminder_definitions)
  end

  def show
    render Views::ReminderDefinitions::Show.new(user: @user, reminder_definition: @reminder_definition)
  end

  def new
    @reminder_definition = @user.reminder_definitions.new
    render Views::ReminderDefinitions::Form.new(user: @user, reminder_definition: @reminder_definition)
  end

  def edit
    render Views::ReminderDefinitions::Form.new(user: @user, reminder_definition: @reminder_definition)
  end

  def create
    @reminder_definition = @user.reminder_definitions.new(reminder_definition_params)
    if @reminder_definition.save
      redirect_to user_reminder_definition_path(@user, @reminder_definition), notice: "Reminder created."
    else
      render Views::ReminderDefinitions::Form.new(user: @user, reminder_definition: @reminder_definition), status: :unprocessable_content
    end
  end

  def update
    if @reminder_definition.update(reminder_definition_params)
      redirect_to user_reminder_definition_path(@user, @reminder_definition), notice: "Reminder updated."
    else
      render Views::ReminderDefinitions::Form.new(user: @user, reminder_definition: @reminder_definition), status: :unprocessable_content
    end
  end

  def destroy
    @reminder_definition.destroy
    redirect_to user_reminder_definitions_path(@user), notice: "Reminder deleted."
  end

  def send_now
    SendReminderJob.perform_later(@reminder_definition.id)
    redirect_to user_reminder_definition_path(@user, @reminder_definition), notice: "Reminder send enqueued."
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_reminder_definition
    @reminder_definition = @user.reminder_definitions.find(params[:id])
  end

  def reminder_definition_params
    params.require(:reminder_definition).permit(:time_of_day)
  end
end
