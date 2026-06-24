class Task < ApplicationRecord
  include HasTimeEstimate

  belongs_to :user
  belongs_to :task_definition, optional: true
  acts_as_list scope: :user

  validates :name, presence: true

  scope :pending, -> { where(done: false) }
  scope :done, -> { where(done: true) }

  def self.next_for(user)
    user.tasks.pending.order(:position).first
  end

  def reminder_body(message_template)
    Liquid::Template.parse(message_template).render("task_name" => name, "link" => link_url, "time_estimate" => time_estimate_label)
  end

  # The task name plus its time estimate, e.g. "Feed the pets (15 min)" - used
  # everywhere a task name appears in an SMS reply outside of the Liquid
  # reminder template (which renders task_name and time_estimate separately).
  def name_with_time_estimate
    time_estimate_label ? "#{name} (#{time_estimate_label})" : name
  end

  def link_url
    return nil if task_definition.nil?

    Rails.application.routes.url_helpers.public_task_definition_url(
      username: task_definition.user.to_param, task_definition_slug: task_definition.to_param,
      host: AppHost.primary, protocol: Rails.env.production? ? "https" : "http"
    )
  end
end
