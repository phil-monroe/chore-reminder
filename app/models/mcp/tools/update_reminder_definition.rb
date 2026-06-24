class Mcp::Tools::UpdateReminderDefinition < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "update_reminder_definition"
  description "Update a household member's scheduled reminder time."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      reminder_definition_id: {type: "integer", description: "The reminder definition's id (see list_reminder_definitions)."},
      time_of_day: {type: "string", description: "24-hour HH:MM, e.g. \"08:00\"."}
    },
    required: ["reminder_definition_id", "time_of_day"]
  )
  annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def self.call(reminder_definition_id:, time_of_day:, server_context:, user_id: nil)
    user = resolve_user(user_id, server_context: server_context)
    reminder_definition = user.reminder_definitions.find(reminder_definition_id)

    if reminder_definition.update(time_of_day: time_of_day)
      MCP::Tool::Response.new([{type: "text", text: "Updated reminder to #{time_of_day}."}])
    else
      MCP::Tool::Response.new([{type: "text", text: reminder_definition.errors.full_messages.to_sentence}], error: true)
    end
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
