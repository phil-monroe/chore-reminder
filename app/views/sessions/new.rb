# The login page itself, reached with no session at all (that's the whole
# point), so it deliberately doesn't extend Views::Base/render inside
# Views::Layouts::ApplicationLayout - that layout's nav links to the
# authenticated admin area, which would be a dead end here, the same
# reasoning as Views::Public::TaskDefinitionShow.
class Views::Sessions::New < Components::Base
  def view_template
    div(class: "min-h-screen flex items-center justify-center bg-gray-50 px-4") do
      div(class: "w-full max-w-sm") do
        h1(class: "text-2xl font-bold text-gray-900 text-center mb-6") { "Chore Reminder" }

        div(class: "bg-white border border-gray-200 rounded-lg shadow-sm p-6") do
          render_flash

          form_with url: login_path, method: :post, class: "space-y-4" do
            div do
              label(for: "password", class: "block text-sm font-medium text-gray-700") { "Password" }
              input(type: "password", name: "password", id: "password", autofocus: true, autocomplete: "current-password",
                class: "mt-1 block w-full rounded-md border border-gray-300 px-3 py-2")
            end

            button(type: "submit", class: "w-full bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700") { "Log in" }
          end
        end
      end
    end
  end

  private

  def render_flash
    return if flash.empty?

    div(class: "space-y-2 mb-4") do
      flash.each do |type, message|
        div(class: flash_classes(type)) { plain message }
      end
    end
  end

  def flash_classes(type)
    base = "rounded-md px-4 py-2 text-sm"
    (type.to_s == "alert") ? "#{base} bg-red-50 text-red-700 border border-red-200" : "#{base} bg-green-50 text-green-700 border border-green-200"
  end
end
