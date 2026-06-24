# Added for parity with the admin UI's destroy action, beyond the
# originally requested action list (see CLAUDE.md "MCP server").
class Mcp::Tools::DeleteTaskDefinition < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "delete_task_definition"
  description "Delete a recurring task definition for a household member."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      task_definition_id: {type: "string", description: "The task definition's slug or numeric id (see list_task_definitions)."}
    },
    required: ["task_definition_id"]
  )
  annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true, open_world_hint: false)

  def self.call(task_definition_id:, server_context:, user_id: nil)
    user = resolve_user(user_id, server_context: server_context)
    task_definition = user.task_definitions.find_by_param!(task_definition_id)
    name = task_definition.name
    task_definition.destroy

    MCP::Tool::Response.new([{type: "text", text: "Deleted task definition \"#{name}\"."}])
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
