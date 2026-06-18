class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy send_test_sms send_message send_welcome_message]

  def index
    @users = User.all
    render Views::Users::Index.new(users: @users)
  end

  def show
    render Views::Users::Show.new(user: @user)
  end

  def new
    @user = User.new
    render Views::Users::Form.new(user: @user)
  end

  def edit
    render Views::Users::Form.new(user: @user)
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to user_path(@user), notice: "User created."
    else
      render Views::Users::Form.new(user: @user), status: :unprocessable_entity
    end
  end

  def update
    if @user.update(user_params)
      redirect_to user_path(@user), notice: "User updated."
    else
      render Views::Users::Form.new(user: @user), status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, notice: "User deleted."
  end

  def send_test_sms
    run_sms_command(success_notice: "Test SMS sent to #{@user.phone_number}.", failure_prefix: "Failed to send test SMS") do
      User::SendMessage.new(user: @user, body: "This is a test message from Chore Reminder.").call
    end
  end

  def send_message
    run_sms_command(success_notice: "Message sent to #{@user.phone_number}.", failure_prefix: "Failed to send message") do
      User::SendMessage.new(user: @user, body: params[:body]).call
    end
  end

  def send_welcome_message
    run_sms_command(success_notice: "Welcome message sent to #{@user.phone_number}.", failure_prefix: "Failed to send welcome message") do
      User::SendWelcomeMessage.new(user: @user).call
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :phone_number, :message_template)
  end

  def run_sms_command(success_notice:, failure_prefix:)
    yield
    redirect_to user_path(@user), notice: success_notice
  rescue User::SendMessage::BlankBodyError => e
    redirect_to user_path(@user), alert: e.message
  rescue KeyError => e
    redirect_to user_path(@user), alert: "Twilio is not configured: #{e.message}"
  rescue Twilio::REST::RestError => e
    redirect_to user_path(@user), alert: "#{failure_prefix}: #{e.message}"
  end
end
