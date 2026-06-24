# Shared header/nav for the unauthenticated marketing/help pages (Home,
# Help) - deliberately not Views::Base/Views::Layouts::ApplicationLayout,
# whose nav links to the authenticated admin area (Dashboard/Users), which
# would be a dead end here, the same reasoning as
# Views::Public::TaskDefinitionShow.
class Views::Pages::Base < Components::Base
  def view_template
    div(class: "min-h-screen flex flex-col") do
      render_header
      main(class: "max-w-3xl mx-auto px-4 py-8 w-full flex-1") do
        div(class: "prose prose-sm max-w-none") { raw safe(doc_html) }
      end
    end
  end

  private

  def doc_html
    raise NotImplementedError, "#{self.class} must implement #doc_html"
  end

  def render_header
    header(class: "bg-white border-b border-gray-200 px-4 py-3") do
      div(class: "max-w-3xl mx-auto flex items-center gap-4") do
        span(class: "font-semibold text-gray-900") { "Chore Reminder" }
        link_to "Features", root_path, class: "text-sm text-gray-600 hover:text-gray-900"
        link_to "Help", help_path, class: "text-sm text-gray-600 hover:text-gray-900"
        link_to "Login", admin_root_path, class: "text-sm text-gray-600 hover:text-gray-900 ml-auto"
      end
    end
  end
end
