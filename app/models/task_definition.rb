class TaskDefinition < ApplicationRecord
  include HasTimeEstimate

  belongs_to :user
  has_many :tasks, dependent: :nullify
  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_limit: [300, 300]
  end

  validates :name, presence: true
  validates :slug, uniqueness: {scope: :user_id}, allow_nil: true
  validates :time_of_day, presence: true
  validate :recurrence_days_are_valid

  before_validation :generate_slug, if: -> { slug.blank? }
  before_validation :compute_next_generate_at, if: -> { new_record? || time_of_day_changed? }

  # Used in URLs (see #to_param) in place of the numeric id when present, so
  # links texted to a household member (Task#link_url) can look friendlier
  # than "/.../42". Generated once from #name (see #generate_slug) and left
  # alone afterwards, so a previously texted link keeps working even if the
  # task definition is later renamed.
  def to_param
    slug.presence || id.to_s
  end

  def self.find_by_param!(param)
    param.match?(/\A\d+\z/) ? find(param) : find_by!(slug: param)
  end

  def recurs_on?(date)
    recurrence_days.include?(date.wday)
  end

  def rendered_description
    return "" if description.blank?

    Commonmarker.to_html(description).html_safe
  end

  private

  def compute_next_generate_at
    TaskDefinition::ComputeNextGenerateAt.new(task_definition: self).call
  end

  # Slugs are scoped per-user (see the uniqueness validation above and the
  # migration's [user_id, slug] index), so two different household members
  # can each have a "take-out-trash" task definition. Falls back to no slug
  # (and to_param falling back to the id) if the name has no parameterizable
  # characters, e.g. an emoji-only name.
  def generate_slug
    return if name.blank?

    base = name.parameterize
    return if base.blank?

    candidate = base
    suffix = 2
    while user.task_definitions.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end

  def recurrence_days_are_valid
    return if recurrence_days.blank?

    unless recurrence_days.all? { |day| (0..6).cover?(day) }
      errors.add(:recurrence_days, "must each be between 0 (Sunday) and 6 (Saturday)")
    end
  end
end
