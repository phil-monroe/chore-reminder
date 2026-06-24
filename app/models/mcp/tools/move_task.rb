# Mirrors Admin::TasksController#move_higher/#move_lower (acts_as_list),
# including the realtime next-task notification.
class Mcp::Tools::MoveTask < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "move_task"
  description "Move a task higher or lower in a household member's list."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      task_id: {type: "integer", description: "The task's id (see list_tasks)."},
      direction: {type: "string", enum: ["higher", "lower"], description: "Move it one position higher (sooner) or lower (later)."}
    },
    required: ["task_id", "direction"]
  )
  annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false)

  def self.call(task_id:, direction:, server_context:, user_id: nil)
    user = resolve_user(user_id, server_context: server_context)
    task = user.tasks.find(task_id)

    previous_next_task_id = Task.next_for(user)&.id
    (direction == "higher") ? task.move_higher : task.move_lower
    NotifyNextTaskChangedJob.perform_later(user.id, previous_next_task_id)

    MCP::Tool::Response.new([{type: "text", text: "Moved \"#{task.name}\" #{direction}."}])
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
