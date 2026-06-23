class TaskDefinition::AdvanceNextGenerateAt
  def initialize(task_definition:)
    @task_definition = task_definition
  end

  def call
    @task_definition.update!(next_generate_at: @task_definition.next_generate_at + 1.day)
  end
end
