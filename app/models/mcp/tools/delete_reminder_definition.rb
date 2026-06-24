# Added for parity with the admin UI's destroy action, beyond the
# originally requested action list (see CLAUDE.md "MCP server").
class Mcp::Tools::DeleteReminderDefinition < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "delete_reminder_definition"
  description "Delete a household member's scheduled reminder time."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      reminder_definition_id: {type: "integer", description: "The reminder definition's id (see list_reminder_definitions)."}
    },
    required: ["reminder_definition_id"]
  )
  annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true, open_world_hint: false)

  def self.call(reminder_definition_id:, server_context:, user_id: nil)
    user = resolve_user(user_id, server_context: server_context)
    reminder_definition = user.reminder_definitions.find(reminder_definition_id)
    reminder_definition.destroy

    MCP::Tool::Response.new([{type: "text", text: "Deleted reminder (id #{reminder_definition_id})."}])
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
