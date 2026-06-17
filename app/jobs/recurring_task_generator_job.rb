class RecurringTaskGeneratorJob < ApplicationJob
  queue_as :default

  def perform
    TaskDefinition.find_each(&:generate_task_for_today!)
  end
end
