# Enqueued after any task list modification (see TasksController and
# User::HandleInboundSms) so the household member hears about a new next
# task right away, instead of waiting for the next scheduled
# ReminderDispatchJob run (up to 15 minutes later, see config/initializers/good_job.rb).
class NotifyNextTaskChangedJob < ApplicationJob
  queue_as :default

  class_attribute :sender_factory, default: -> { Sms::TwilioSender.new }

  retry_on Twilio::REST::RestError, wait: :polynomially_longer, attempts: 5

  def perform(user_id, previous_next_task_id)
    user = User.find(user_id)

    User::NotifyIfNextTaskChanged.new(
      user: user, previous_next_task_id: previous_next_task_id, sender: sender_factory.call
    ).call
  end
end
