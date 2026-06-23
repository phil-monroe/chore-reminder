class TaskGenerationDispatchJob < ApplicationJob
  queue_as :default

  def perform
    TaskDefinition.where("next_generate_at <= ?", Time.current).find_each do |task_definition|
      TaskDefinition::AdvanceNextGenerateAt.new(task_definition: task_definition).call
      TaskDefinition::GenerateForToday.new(task_definition: task_definition).call
    end
  end
end
