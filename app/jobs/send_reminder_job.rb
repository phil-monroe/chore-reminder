class SendReminderJob < ApplicationJob
  queue_as :default

  class_attribute :sender_factory, default: -> { Sms::TwilioSender.new }

  retry_on Twilio::REST::RestError, wait: :polynomially_longer, attempts: 5

  def perform(reminder_definition_id)
    reminder = ReminderDefinition.find(reminder_definition_id)
    return if reminder.user.snoozed?

    task = Task.next_for(reminder.user)
    return if task.nil?

    # Routed through User::SendMessage (rather than calling the sender
    # directly) so this, like every other outbound text, gets logged for the
    # conversation view (see User::SendMessage).
    User::SendMessage.new(
      user: reminder.user, body: task.reminder_body(reminder.user.message_template), sender: sender_factory.call
    ).call
  end
end
