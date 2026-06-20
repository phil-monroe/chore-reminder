class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy new_message send_message send_welcome_message conversation send_inbound_message]
  around_action :with_time_zone, only: %i[conversation send_inbound_message]

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
      render Views::Users::Form.new(user: @user), status: :unprocessable_content
    end
  end

  def update
    if @user.update(user_params)
      redirect_to user_path(@user), notice: "User updated."
    else
      render Views::Users::Form.new(user: @user), status: :unprocessable_content
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, notice: "User deleted."
  end

  def new_message
    render Views::Users::NewMessage.new(user: @user)
  end

  def send_message
    run_sms_command(success_notice: "Message sent to #{@user.phone_number}.", failure_prefix: "Failed to send message",
      redirect_path: new_message_user_path(@user)) do
      User::SendMessage.new(user: @user, body: params[:body]).call
    end
  end

  def send_welcome_message
    run_sms_command(success_notice: "Welcome message sent to #{@user.phone_number}.", failure_prefix: "Failed to send welcome message") do
      User::SendWelcomeMessage.new(user: @user).call
    end
  end

  def conversation
    @messages = @user.messages.order(:created_at)
    render Views::Users::Conversation.new(user: @user, messages: @messages)
  end

  # Simulates an inbound text from this user without needing their actual
  # phone — runs the same DONE/SKIP/NEXT/ADD handling as the real Twilio
  # webhook (Integrations::TwilioController), just triggered from the
  # conversation view instead of a signed Twilio request. Unlike the real
  # webhook (whose reply is delivered by Twilio responding to the request),
  # deliver_reply: true here actually sends the reply as a real outbound
  # text, since there's no webhook response to ride along on.
  def send_inbound_message
    run_sms_command(success_notice: nil, failure_prefix: "Failed to send reply",
      redirect_path: conversation_user_path(@user)) do
      User::HandleInboundSms.new(user: @user, body: params[:body], deliver_reply: true).call
    end
  end

  private

  def set_user
    @user = User.find_by_param!(params[:id])
  end

  def with_time_zone(&block)
    Time.use_zone(@user.time_zone, &block)
  end

  def user_params
    params.require(:user).permit(:name, :username, :phone_number, :message_template, :time_zone)
  end

  def run_sms_command(success_notice:, failure_prefix:, redirect_path: user_path(@user))
    yield
    redirect_to redirect_path, notice: success_notice
  rescue User::SendMessage::BlankBodyError => e
    redirect_to redirect_path, alert: e.message
  rescue KeyError => e
    redirect_to redirect_path, alert: "Twilio is not configured: #{e.message}"
  rescue Twilio::REST::RestError => e
    redirect_to redirect_path, alert: "#{failure_prefix}: #{e.message}"
  end
end
