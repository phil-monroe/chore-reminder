class Mcp::Tools::UpdateTaskDefinition < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "update_task_definition"
  description "Update an existing recurring task definition for a household member."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      task_definition_id: {type: "string", description: "The task definition's slug or numeric id (see list_task_definitions)."},
      name: {type: "string"},
      description: {type: "string", description: "Markdown description shown on the task's public page."},
      time_of_day: {type: "string", description: "24-hour HH:MM, e.g. \"08:00\"."},
      recurrence_days: {type: "array", items: {type: "integer", minimum: 0, maximum: 6}, description: "Days of week it generates on (0 = Sunday .. 6 = Saturday). Omit/empty for every day."},
      time_estimate_minutes: {type: "integer", description: "Optional - how long this task is expected to take, in minutes. Copied onto each generated task."}
    },
    required: ["task_definition_id"]
  )
  annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def self.call(task_definition_id:, server_context:, user_id: nil, name: nil, description: nil, time_of_day: nil, recurrence_days: nil, time_estimate_minutes: nil)
    user = resolve_user(user_id, server_context: server_context)
    task_definition = user.task_definitions.find_by_param!(task_definition_id)

    attributes = {name: name, description: description, time_of_day: time_of_day, recurrence_days: recurrence_days, time_estimate_minutes: time_estimate_minutes}.compact
    if task_definition.update(attributes)
      MCP::Tool::Response.new([{type: "text", text: "Updated task definition \"#{task_definition.name}\"."}])
    else
      MCP::Tool::Response.new([{type: "text", text: task_definition.errors.full_messages.to_sentence}], error: true)
    end
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
