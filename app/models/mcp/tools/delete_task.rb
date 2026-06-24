# Mirrors Admin::TasksController#destroy, including the realtime next-task
# notification.
class Mcp::Tools::DeleteTask < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "delete_task"
  description "Delete a task from a household member's list."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      task_id: {type: "integer", description: "The task's id (see list_tasks)."}
    },
    required: ["task_id"]
  )
  annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true, open_world_hint: false)

  def self.call(task_id:, server_context:, user_id: nil)
    user = resolve_user(user_id, server_context: server_context)
    task = user.tasks.find(task_id)

    previous_next_task_id = Task.next_for(user)&.id
    name = task.name
    task.destroy
    NotifyNextTaskChangedJob.perform_later(user.id, previous_next_task_id)

    MCP::Tool::Response.new([{type: "text", text: "Deleted \"#{name}\"."}])
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
