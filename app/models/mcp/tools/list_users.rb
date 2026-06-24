class Mcp::Tools::ListUsers < MCP::Tool
  tool_name "list_users"
  description "List every household member, with their id, username, name, phone number, and time zone."
  input_schema(properties: {})
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def self.call(server_context:)
    users = User.all.map do |user|
      {id: user.id, username: user.username, name: user.name, phone_number: user.phone_number, time_zone: user.time_zone}
    end

    MCP::Tool::Response.new([{type: "text", text: users.to_json}], structured_content: {users: users})
  end
end
