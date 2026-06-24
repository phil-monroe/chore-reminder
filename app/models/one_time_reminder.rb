class OneTimeReminder < ApplicationRecord
  belongs_to :user

  validates :send_at, presence: true
end
