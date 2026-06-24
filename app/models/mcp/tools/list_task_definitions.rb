class Mcp::Tools::ListTaskDefinitions < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "list_task_definitions"
  description "List a household member's recurring task definitions (the templates that generate daily tasks)."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."}
    }
  )
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def self.call(server_context:, user_id: nil)
    user = resolve_user(user_id, server_context: server_context)

    definitions = user.task_definitions.map do |td|
      {id: td.id, slug: td.slug, name: td.name, description: td.description, time_of_day: td.time_of_day.strftime("%H:%M"), recurrence_days: td.recurrence_days, time_estimate_minutes: td.time_estimate_minutes}
    end

    MCP::Tool::Response.new([{type: "text", text: definitions.to_json}], structured_content: {task_definitions: definitions})
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
