class Task < ApplicationRecord
  belongs_to :user
  belongs_to :task_definition, optional: true
  acts_as_list scope: :user

  validates :name, presence: true

  scope :pending, -> { where(done: false) }

  def self.next_for(user)
    user.tasks.pending.order(:position).first
  end
end
