class User < ApplicationRecord
  has_many :tasks, dependent: :destroy
  has_many :task_definitions, dependent: :destroy
  has_many :reminder_definitions, dependent: :destroy

  validates :name, presence: true
  validates :phone_number, presence: true, format: { with: /\A\+[1-9]\d{6,14}\z/ }
  validates :message_template, presence: true
  validate :message_template_is_valid_liquid

  private

  def message_template_is_valid_liquid
    Liquid::Template.parse(message_template) if message_template.present?
  rescue Liquid::SyntaxError => e
    errors.add(:message_template, "is not valid Liquid: #{e.message}")
  end
end
