# Shared by every Mcp::Tools::* tool to resolve which User it should act
# on. An access token is always issued for one household member (see
# Oauth::AuthorizationsController), available here as
# `server_context[:current_user]` - tools default to that user when called
# without an explicit `user_id`, which is what makes "my tasks"-style usage
# work, while still letting the caller name any user explicitly since an
# admin-level token can act on the whole household, not just the one it
# defaults to.
module Mcp::Tools::ResolvesUser
  def resolve_user(user_id, server_context:)
    return server_context[:current_user] if user_id.blank?

    User.find_by_param!(user_id)
  end
end
