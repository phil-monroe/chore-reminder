# Mirrors Admin::TasksController#toggle_done, including the realtime
# next-task notification (see CLAUDE.md "Realtime next task notifications").
class Mcp::Tools::ToggleTask < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "toggle_task"
  description "Toggle a task's done state for a household member."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      task_id: {type: "integer", description: "The task's id (see list_tasks)."}
    },
    required: ["task_id"]
  )
  annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false)

  def self.call(task_id:, server_context:, user_id: nil)
    user = resolve_user(user_id, server_context: server_context)
    task = user.tasks.find(task_id)

    previous_next_task_id = Task.next_for(user)&.id
    task.update!(done: !task.done)
    NotifyNextTaskChangedJob.perform_later(user.id, previous_next_task_id)

    MCP::Tool::Response.new([{type: "text", text: "\"#{task.name}\" is now #{task.done ? "done" : "pending"}."}])
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
