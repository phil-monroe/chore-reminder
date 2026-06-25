# Landing page for caregiver-facing configuration that isn't tied to a
# specific household member, e.g. connected apps (see CLAUDE.md "MCP
# server"). A single index page that links out to each settings area,
# rather than its own controller, since right now there's only one.
class Admin::SettingsController < Admin::BaseController
  def index
    render Views::Admin::Settings::Index.new
  end
end
