class TaskDefinition::ComputeNextGenerateAt
  def initialize(task_definition:)
    @task_definition = task_definition
  end

  def call
    return if @task_definition.time_of_day.blank?

    zone = @task_definition.user.time_zone_object
    candidate = zone.now.change(hour: @task_definition.time_of_day.hour, min: @task_definition.time_of_day.min)
    @task_definition.next_generate_at = (candidate > zone.now) ? candidate : candidate + 1.day
  end
end
