class ReminderDispatchJob < ApplicationJob
  queue_as :default

  def perform
    ReminderDefinition.where("next_send_at <= ?", Time.current).find_each do |reminder|
      reminder.advance!
      SendReminderJob.perform_later(reminder.id)
    end
  end
end
