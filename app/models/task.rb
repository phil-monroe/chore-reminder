class Task < ApplicationRecord
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
    Liquid::Template.parse(message_template).render("task_name" => name, "link" => link_url)
  end

  def link_url
    return nil if task_definition.nil?

    Rails.application.routes.url_helpers.user_task_definition_url(
      task_definition.user, task_definition,
      host: AppHost.primary, protocol: Rails.env.production? ? "https" : "http"
    )
  end
end
