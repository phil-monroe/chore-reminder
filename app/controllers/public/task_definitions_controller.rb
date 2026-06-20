# Unauthenticated counterpart to Admin::TaskDefinitionsController#show - the
# page linked from reminder texts (see Task#link_url), reached by household
# members who have no Basic Auth credentials (see config/routes.rb and
# app/middleware/basic_auth_admin_gate.rb, which only gates /admin).
# Deliberately doesn't expose anything beyond what's already texted to
# them: no edit/generate controls, no other users' or task definitions' data.
class Public::TaskDefinitionsController < ApplicationController
  def show
    user = User.find_by_param!(params[:username])
    @task_definition = user.task_definitions.find_by_param!(params[:task_definition_slug])
    render Views::Public::TaskDefinitionShow.new(task_definition: @task_definition)
  end
end
