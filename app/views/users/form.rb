class Views::Users::Form < Views::Base
  def initialize(user:)
    @user = user
  end

  def page_content
    h1(class: "text-2xl font-bold text-gray-900 mb-6") { @user.persisted? ? "Edit #{@user.name}" : "New user" }

    render_errors

    form_with model: @user, url: form_url, class: "space-y-4" do |f|
      div do
        f.label :name, class: "block text-sm font-medium text-gray-700"
        f.text_field :name, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
      end

      div do
        f.label :phone_number, class: "block text-sm font-medium text-gray-700"
        f.text_field :phone_number, placeholder: "+15555550100", class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2"
      end

      div do
        f.label :message_template, class: "block text-sm font-medium text-gray-700"
        p(class: "text-xs text-gray-500 mb-1") { "Liquid template. Available variables: {{ task_name }}, {{ link }} (use {% if link %}...{% endif %} since link may be blank)." }
        f.text_area :message_template, rows: 4, class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 font-mono text-sm"
      end

      div(class: "flex items-center gap-3") do
        f.submit class: "bg-blue-600 text-white px-4 py-2 rounded-md text-sm hover:bg-blue-700"
        link_to "Cancel", cancel_url, class: "text-sm text-gray-600 hover:underline"
      end
    end
  end

  private

  def form_url
    @user.persisted? ? user_path(@user) : users_path
  end

  def cancel_url
    @user.persisted? ? user_path(@user) : users_path
  end

  def render_errors
    return if @user.errors.empty?

    div(class: "bg-red-50 border border-red-200 text-red-700 rounded-md p-3 mb-4 text-sm") do
      ul do
        @user.errors.full_messages.each { |msg| li { msg } }
      end
    end
  end
end
