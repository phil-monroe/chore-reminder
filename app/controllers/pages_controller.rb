# Unauthenticated marketing/help pages, reachable with no Basic Auth
# credentials (see app/middleware/basic_auth_admin_gate.rb, which only gates
# /admin) - the same as the public per-task page
# (Public::TaskDefinitionsController). "/" is a high-level features
# overview (FEATURES.md); "/help" is a how-to knowledge base (HOW_TO.md).
# Both render the actual repo markdown files, via Commonmarker, so there's
# one source of truth rather than the docs and the page content drifting
# apart - the same approach TaskDefinition#rendered_description uses.
class PagesController < ApplicationController
  def home
    render Views::Pages::Home.new(html: rendered_doc("FEATURES.md"))
  end

  def help
    render Views::Pages::Help.new(html: rendered_doc("HOW_TO.md"))
  end

  private

  def rendered_doc(filename)
    Commonmarker.to_html(Rails.root.join(filename).read).html_safe
  end
end
