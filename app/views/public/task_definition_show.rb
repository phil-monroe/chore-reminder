# Deliberately doesn't extend Views::Base/render inside
# Views::Layouts::ApplicationLayout directly - that layout's <main> is wider
# (max-w-3xl) than this page wants for a single task on a phone screen. The
# nav itself (Views::Layouts::Nav) is shared with ApplicationLayout and
# Views::Pages::Base, narrowed to match this page's content width.
class Views::Public::TaskDefinitionShow < Components::Base
  def initialize(task_definition:)
    @task_definition = task_definition
  end

  def view_template
    div(class: "min-h-screen flex flex-col") do
      render Views::Layouts::Nav.new(container_class: "max-w-md mx-auto")
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
