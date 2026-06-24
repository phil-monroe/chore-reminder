class Mcp::Tools::CreateReminderDefinition < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "create_reminder_definition"
  description "Create a new scheduled reminder time for a household member."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      time_of_day: {type: "string", description: "24-hour HH:MM, e.g. \"08:00\"."}
    },
    required: ["time_of_day"]
  )
  annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false)

  def self.call(time_of_day:, server_context:, user_id: nil)
    user = resolve_user(user_id, server_context: server_context)
    reminder_definition = user.reminder_definitions.new(time_of_day: time_of_day)

    if reminder_definition.save
      MCP::Tool::Response.new([{type: "text", text: "Created reminder for #{time_of_day} (id #{reminder_definition.id})."}])
    else
      MCP::Tool::Response.new([{type: "text", text: reminder_definition.errors.full_messages.to_sentence}], error: true)
    end
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
