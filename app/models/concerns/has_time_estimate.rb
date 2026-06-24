module HasTimeEstimate
  extend ActiveSupport::Concern

  included do
    validates :time_estimate_minutes, numericality: {only_integer: true, greater_than: 0}, allow_nil: true
  end

  # Formatted for display/SMS, e.g. "15 min", "1 hr", "1 hr 30 min" - or nil
  # when no estimate has been set, so callers can decide whether to show
  # anything at all.
  def time_estimate_label
    return nil if time_estimate_minutes.nil?

    hours, minutes = time_estimate_minutes.divmod(60)
    [hours.positive? ? "#{hours} hr" : nil, minutes.positive? ? "#{minutes} min" : nil].compact.join(" ")
  end
end
