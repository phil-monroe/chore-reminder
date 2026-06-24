# Shared layout for the marketing/help pages (Home, Help) - not
# Views::Base/Views::Layouts::ApplicationLayout, since that layout's <main>
# is narrower (max-w-3xl is shared, but the admin layout also wraps flash
# messages this page has none of). The nav itself (Views::Layouts::Nav) is
# shared with ApplicationLayout and Views::Public::TaskDefinitionShow.
class Views::Pages::Base < Components::Base
  def view_template
    div(class: "min-h-screen flex flex-col") do
      render Views::Layouts::Nav.new
      main(class: "max-w-3xl mx-auto px-4 py-8 w-full flex-1") do
        div(class: "prose prose-sm max-w-none") { raw safe(doc_html) }
      end
    end
  end

  private

  def doc_html
    raise NotImplementedError, "#{self.class} must implement #doc_html"
  end
end
