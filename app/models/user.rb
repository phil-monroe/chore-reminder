class User < ApplicationRecord
  has_many :tasks, dependent: :destroy
  has_many :task_definitions, dependent: :destroy
  has_many :reminder_definitions, dependent: :destroy
  has_many :messages, dependent: :destroy

  validates :name, presence: true
  validates :phone_number, presence: true, format: {with: /\A\+[1-9]\d{6,14}\z/}
  validates :message_template, presence: true
  validates :time_zone, presence: true, inclusion: {in: ActiveSupport::TimeZone::MAPPING.values}
  validates :username, uniqueness: true, allow_blank: true,
    format: {with: /\A[a-z0-9_-]*[a-z_-][a-z0-9_-]*\z/, message: "can only contain lowercase letters, numbers, underscores, and hyphens, and can't be purely numeric"}
  validate :message_template_is_valid_liquid

  # Normalizes away the most common ways a username could end up invalid
  # without the person intending it - a phone keyboard's autocapitalized
  # first letter, or leading/trailing whitespace from autofill - rather than
  # rejecting those at validation and forcing a manual retype.
  before_validation { self.username = username.strip.downcase if username.present? }

  # Used in URLs (see #to_param) in place of the numeric id when present, so
  # links texted to a household member (e.g. SendReminderJob/Task#link_url)
  # can look friendlier than "/42/...". The format validation above requires
  # at least one non-digit character, so a purely-numeric param below is
  # unambiguously an id rather than a username.
  def to_param
    username.presence || id.to_s
  end

  def self.find_by_param!(param)
    param.match?(/\A\d+\z/) ? find(param) : find_by!(username: param)
  end

  def time_zone_object
    ActiveSupport::TimeZone[time_zone]
  end

  # Set by the SNOOZE SMS command (see User::HandleInboundSms) to pause
  # outbound reminders/next-task notifications without modifying the
  # underlying ReminderDefinition schedule itself.
  def snoozed?
    snoozed_until.present? && snoozed_until > Time.current
  end

  private

  def message_template_is_valid_liquid
    Liquid::Template.parse(message_template) if message_template.present?
  rescue Liquid::SyntaxError => e
    errors.add(:message_template, "is not valid Liquid: #{e.message}")
  end
end
