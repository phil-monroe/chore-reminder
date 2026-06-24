class Mcp::Tools::ListReminderDefinitions < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "list_reminder_definitions"
  description "List a household member's scheduled reminder times."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."}
    }
  )
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def self.call(server_context:, user_id: nil)
    user = resolve_user(user_id, server_context: server_context)

    definitions = user.reminder_definitions.map do |rd|
      {id: rd.id, time_of_day: rd.time_of_day.strftime("%H:%M"), next_send_at: rd.next_send_at}
    end

    MCP::Tool::Response.new([{type: "text", text: definitions.to_json}], structured_content: {reminder_definitions: definitions})
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
