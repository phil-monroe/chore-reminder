class SendReminderJob < ApplicationJob
  queue_as :default

  class_attribute :sender_factory, default: -> { Sms::TwilioSender.new }

  retry_on Twilio::REST::RestError, wait: :polynomially_longer, attempts: 5

  def perform(reminder_definition_id)
    reminder = ReminderDefinition.find(reminder_definition_id)
    task = Task.next_for(reminder.user)
    return if task.nil?

    body = Liquid::Template.parse(reminder.user.message_template).render(
      "task_name" => task.name,
      "link" => link_for(task)
    )

    sender_factory.call.send(to: reminder.user.phone_number, body: body)
  end

  private

  def link_for(task)
    return nil if task.task_definition.nil?

    Rails.application.routes.url_helpers.user_task_definition_url(
      task.task_definition.user, task.task_definition, host: AppHost.primary
    )
  end
end
