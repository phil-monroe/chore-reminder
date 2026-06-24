class TaskDefinition::GenerateForToday
  def initialize(task_definition:)
    @task_definition = task_definition
  end

  # Skips generating if there's already a pending (not-yet-done) task for
  # this definition, rather than just checking whether one was already
  # generated today - otherwise an incomplete task from a previous day would
  # pile up a second, duplicate task once it recurs again, instead of the
  # original staying the one and only outstanding instance until it's
  # actually done.
  def call
    return unless @task_definition.recurs_on?(Date.current)
    return if @task_definition.tasks.pending.exists?

    user = @task_definition.user
    previous_next_task_id = Task.next_for(user)&.id
    task = @task_definition.tasks.create!(name: @task_definition.name, user: user, done: false, time_estimate_minutes: @task_definition.time_estimate_minutes)
    NotifyNextTaskChangedJob.perform_later(user.id, previous_next_task_id)
    task
  end
end
