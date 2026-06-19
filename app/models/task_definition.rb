class TaskDefinition < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :nullify
  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_limit: [300, 300]
  end

  validates :name, presence: true
  validate :recurrence_days_are_valid

  def recurs_on?(date)
    recurrence_days.include?(date.wday)
  end

  def rendered_description
    return "" if description.blank?

    Commonmarker.to_html(description).html_safe
  end

  def generate_task_for_today!
    return unless recurs_on?(Date.current)
    return if tasks.where(created_at: Date.current.all_day).exists?

    previous_next_task_id = Task.next_for(user)&.id
    task = tasks.create!(name: name, user: user, done: false)
    NotifyNextTaskChangedJob.perform_later(user.id, previous_next_task_id)
    task
  end

  private

  def recurrence_days_are_valid
    return if recurrence_days.blank?

    unless recurrence_days.all? { |day| (0..6).cover?(day) }
      errors.add(:recurrence_days, "must each be between 0 (Sunday) and 6 (Saturday)")
    end
  end
end
