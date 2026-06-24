# Mirrors Admin::TasksController#create (an ad-hoc, one-off task, as
# opposed to create_task_definition's recurring template), including the
# realtime next-task notification.
class Mcp::Tools::CreateTask < MCP::Tool
  extend Mcp::Tools::ResolvesUser

  tool_name "create_task"
  description "Add a new one-off task to a household member's list. For a chore that repeats on a schedule, use create_task_definition instead."
  input_schema(
    properties: {
      user_id: {type: "string", description: "Username or numeric id. Defaults to the household member this connection acts as."},
      name: {type: "string"},
      task_definition_id: {type: "integer", description: "Optional - links this task back to a recurring task definition (see list_task_definitions)."}
    },
    required: ["name"]
  )
  annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false)

  def self.call(name:, server_context:, user_id: nil, task_definition_id: nil)
    user = resolve_user(user_id, server_context: server_context)

    previous_next_task_id = Task.next_for(user)&.id
    task = user.tasks.new(name: name, task_definition_id: task_definition_id)

    if task.save
      NotifyNextTaskChangedJob.perform_later(user.id, previous_next_task_id)
      MCP::Tool::Response.new([{type: "text", text: "Added \"#{task.name}\" (id #{task.id})."}])
    else
      MCP::Tool::Response.new([{type: "text", text: task.errors.full_messages.to_sentence}], error: true)
    end
  rescue ActiveRecord::RecordNotFound => e
    MCP::Tool::Response.new([{type: "text", text: e.message}], error: true)
  end
end
