# Mirrors Admin::TaskDefinitionsController#create / #task_definition_params -
# same permitted fields, minus `images` (a file upload isn't meaningful over
# MCP).
class Mcp::Tools::CreateTaskDefinition < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "create_task_definition"
  description "Create a new recurring task definition for a household member."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      name: {type: "string"},
      description: {type: "string", description: "Markdown description shown on the task's public page."},
      time_of_day: {type: "string", description: "24-hour HH:MM, e.g. \"08:00\"."},
      recurrence_days: {type: "array", items: {type: "integer", minimum: 0, maximum: 6}, description: "Days of week it generates on (0 = Sunday .. 6 = Saturday). Omit/empty for every day."},
      time_estimate_minutes: {type: "integer", description: "Optional - how long this task is expected to take, in minutes. Copied onto each generated task."}
    },
    required: ["name", "time_of_day"]
  )
  annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false)

  def self.call(name:, time_of_day:, server_context:, user_id: nil, description: nil, recurrence_days: nil, time_estimate_minutes: nil)
    user = resolve_user(user_id, server_context: server_context)
    task_definition = user.task_definitions.new(name: name, description: description, time_of_day: time_of_day, recurrence_days: recurrence_days || [], time_estimate_minutes: time_estimate_minutes)

    if task_definition.save
      MCP::Tool::Response.new([{type: "text", text: "Created task definition \"#{task_definition.name}\" (id #{task_definition.id})."}])
    else
      MCP::Tool::Response.new([{type: "text", text: task_definition.errors.full_messages.to_sentence}], error: true)
    end
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
