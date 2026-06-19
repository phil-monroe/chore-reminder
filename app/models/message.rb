class Message < ApplicationRecord
  belongs_to :user

  enum :direction, {inbound: "inbound", outbound: "outbound"}, validate: true

  validates :body, presence: true
end
