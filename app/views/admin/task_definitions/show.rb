class Views::TaskDefinitions::Show < Views::Base
  def initialize(user:, task_definition:)
    @user = user
    @task_definition = task_definition
  end

  def page_content
    link_to "← Back to task definitions", user_task_definitions_path(@user), class: "text-sm text-blue-600 hover:underline block mb-4"

    div(class: "flex items-center justify-between mb-6") do
      h1(class: "text-2xl font-bold text-gray-900") { @task_definition.name }
      link_to "Edit", edit_user_task_definition_path(@user, @task_definition), class: "text-sm text-blue-600 hover:underline"
    end

    div(class: "bg-white border border-gray-200 rounded-lg p-4 mb-6 prose prose-sm max-w-none") do
      raw safe(@task_definition.rendered_description)
    end

    images_section

    div(class: "flex gap-3") do
      button_to "Generate today's task now", generate_now_user_task_definition_path(@user, @task_definition), method: :post,
        class: "bg-gray-800 text-white px-3 py-1.5 rounded-md text-sm hover:bg-gray-900"
    end
  end

  private

  def images_section
    return unless @task_definition.images.attached?

    div(class: "mb-6") do
      h2(class: "text-sm font-medium text-gray-700 mb-2") { "Images" }
      div(class: "flex flex-wrap gap-3") do
        @task_definition.images.each do |image|
          link_to url_for(image), target: "_blank", rel: "noopener" do
            img(src: url_for(image.variant(:thumb)), class: "rounded-md border border-gray-200", alt: @task_definition.name)
          end
        end
      end
    end
  end
end
