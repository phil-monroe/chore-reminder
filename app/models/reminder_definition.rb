class ReminderDefinition < ApplicationRecord
  belongs_to :user

  validates :time_of_day, presence: true

  before_validation :compute_next_send_at, if: -> { new_record? || time_of_day_changed? }

  def advance!
    update!(next_send_at: next_send_at + 1.day)
  end

  private

  def compute_next_send_at
    return if time_of_day.blank?

    zone = user.time_zone_object
    candidate = zone.now.change(hour: time_of_day.hour, min: time_of_day.min)
    self.next_send_at = (candidate > zone.now) ? candidate : candidate + 1.day
  end
end
