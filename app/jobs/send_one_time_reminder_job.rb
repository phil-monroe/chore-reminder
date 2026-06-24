class SendOneTimeReminderJob < ApplicationJob
  queue_as :default

  class_attribute :sender_factory, default: -> { Sms::TwilioSender.new }

  retry_on Twilio::REST::RestError, wait: :polynomially_longer, attempts: 5

  # Deliberately doesn't check User#snoozed? the way SendReminderJob does:
  # snooze pauses the recurring nag reminders, but a one-time REMIND is an
  # explicit request the household member just made, so it should fire
  # regardless.
  def perform(user_id)
    user = User.find(user_id)
    task = Task.next_for(user)
    return if task.nil?

    User::SendMessage.new(
      user: user, body: task.reminder_body(user.message_template), sender: sender_factory.call
    ).call
  end
end
