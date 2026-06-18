class UsersController < ApplicationController
  class_attribute :sms_sender_factory, default: -> { Sms::TwilioSender.new }

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
    send_sms(body: "This is a test message from Chore Reminder.",
      success_notice: "Test SMS sent to #{@user.phone_number}.",
      failure_prefix: "Failed to send test SMS")
  end

  def send_message
    body = params[:body].to_s.strip
    return redirect_to user_path(@user), alert: "Message can't be blank." if body.blank?

    send_sms(body: body,
      success_notice: "Message sent to #{@user.phone_number}.",
      failure_prefix: "Failed to send message")
  end

  def send_welcome_message
    send_sms(body: @user.welcome_message_body,
      success_notice: "Welcome message sent to #{@user.phone_number}.",
      failure_prefix: "Failed to send welcome message")
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :phone_number, :message_template)
  end

  def send_sms(body:, success_notice:, failure_prefix:)
    sms_sender_factory.call.send(to: @user.phone_number, body: body)
    redirect_to user_path(@user), notice: success_notice
  rescue KeyError => e
    redirect_to user_path(@user), alert: "Twilio is not configured: #{e.message}"
  rescue Twilio::REST::RestError => e
    redirect_to user_path(@user), alert: "#{failure_prefix}: #{e.message}"
  end
end
