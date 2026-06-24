# The full set of tools the MCP server (Mcp::ServerController) exposes -
# every action listed in CLAUDE.md's "MCP server" section. Kept as one list
# in its own file rather than scattered `MCP::Server.new` calls so the
# registry has a single source of truth.
module Mcp::ToolRegistry
  def self.all
    [
      Mcp::Tools::ListUsers,
      Mcp::Tools::ListTasks,
      Mcp::Tools::CreateTask,
      Mcp::Tools::ToggleTask,
      Mcp::Tools::MoveTask,
      Mcp::Tools::DeleteTask,
      Mcp::Tools::ListTaskDefinitions,
      Mcp::Tools::CreateTaskDefinition,
      Mcp::Tools::UpdateTaskDefinition,
      Mcp::Tools::DeleteTaskDefinition,
      Mcp::Tools::ListReminderDefinitions,
      Mcp::Tools::CreateReminderDefinition,
      Mcp::Tools::UpdateReminderDefinition,
      Mcp::Tools::DeleteReminderDefinition
    ]
  end
end
