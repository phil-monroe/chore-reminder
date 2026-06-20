# Deliberately doesn't extend Views::Base/render inside
# Views::Layouts::ApplicationLayout - that layout's nav links to the
# authenticated admin area (Dashboard/Users), which would be a dead end for
# the unauthenticated household member viewing this page.
class Views::Public::TaskDefinitionShow < Components::Base
  def initialize(task_definition:)
    @task_definition = task_definition
  end

  def view_template
    div(class: "min-h-screen flex flex-col") do
      render_header
      main(class: "max-w-md mx-auto px-4 py-8 w-full flex-1") do
        h1(class: "text-2xl font-bold text-gray-900 mb-4") { @task_definition.name }

        if @task_definition.rendered_description.present?
          div(class: "prose prose-sm max-w-none mb-6") { raw safe(@task_definition.rendered_description) }
        end

        images_section
      end
    end
  end

  private

  # A login link rather than the full admin nav (Dashboard/Users, see
  # Views::Layouts::ApplicationLayout) - those are dead ends for someone not
  # yet authenticated. Tapping this hits /admin, which is gated by
  # BasicAuthAdminGate, prompting the browser's native Basic Auth dialog;
  # logging in there lands on the admin dashboard.
  def render_header
    header(class: "bg-white border-b border-gray-200 px-4 py-3") do
      div(class: "max-w-md mx-auto flex items-center justify-between") do
        span(class: "font-semibold text-gray-900") { "Chore Reminder" }
        link_to "Login", admin_root_path, class: "text-sm text-gray-600 hover:text-gray-900"
      end
    end
  end

  def images_section
    return unless @task_definition.images.attached?

    div(class: "flex flex-wrap gap-3") do
      @task_definition.images.each do |image|
        link_to url_for(image), target: "_blank", rel: "noopener" do
          img(src: url_for(image.variant(:thumb)), class: "rounded-md border border-gray-200", alt: @task_definition.name)
        end
      end
    end
  end
end
