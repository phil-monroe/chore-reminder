class OneTimeReminderDispatchJob < ApplicationJob
  queue_as :default

  def perform
    OneTimeReminder.where("send_at <= ?", Time.current).find_each do |reminder|
      user_id = reminder.user_id
      reminder.destroy!
      SendOneTimeReminderJob.perform_later(user_id)
    end
  end
end
