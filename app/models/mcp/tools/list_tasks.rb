# Mirrors Admin::TasksController#tasks_for_filter: pending tasks ordered by
# position (the order they'd be texted in) by default, or recently
# completed tasks (capped the same way the admin "done" tab is) when
# done: true.
class Mcp::Tools::ListTasks < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "list_tasks"
  description "List a household member's tasks - pending (default, ordered the way they'll be texted) or recently done."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      done: {type: "boolean", description: "List recently completed tasks instead of pending ones. Defaults to false."}
    }
  )
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def self.call(server_context:, user_id: nil, done: false)
    user = resolve_user(user_id, server_context: server_context)

    tasks = done ? user.tasks.done.where(updated_at: 2.weeks.ago..).order(updated_at: :desc) : user.tasks.pending.order(:position)
    tasks = tasks.map { |task| {id: task.id, name: task.name, done: task.done, position: task.position, task_definition_id: task.task_definition_id, time_estimate_minutes: task.time_estimate_minutes} }

    MCP::Tool::Response.new([{type: "text", text: tasks.to_json}], structured_content: {tasks: tasks})
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
