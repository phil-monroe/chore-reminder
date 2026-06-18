class Views::Layouts::ApplicationLayout < Views::Base
  def view_template(&block)
    div(class: "min-h-screen") do
      render_nav
      render_flash
      main(class: "max-w-3xl mx-auto px-4 py-6") do
        yield
      end
      render_build_info
    end
  end

  private

  def render_build_info
    sha = ENV["GIT_SHA"]
    return if sha.blank?

    div(class: "max-w-3xl mx-auto px-4 py-2 text-right") do
      span(class: "text-xs text-gray-300", title: ENV["GIT_COMMIT_MESSAGE"]) do
        plain [sha[0, 7], ENV["GIT_REF"]].compact_blank.join(" @ ")
      end
    end
  end

  def render_nav
    nav(class: "bg-white border-b border-gray-200 px-4 py-3") do
      div(class: "max-w-3xl mx-auto flex items-center gap-4") do
        link_to "Chore Reminder", root_path, class: "font-semibold text-gray-900"
        link_to "Dashboard", root_path, class: "text-sm text-gray-600 hover:text-gray-900"
        link_to "Users", users_path, class: "text-sm text-gray-600 hover:text-gray-900"
      end
    end
  end

  def render_flash
    return if flash.empty?

    div(class: "max-w-3xl mx-auto px-4 pt-4 space-y-2") do
      flash.each do |type, message|
        div(class: flash_classes(type)) { plain message }
      end
    end
  end

  def flash_classes(type)
    base = "rounded-md px-4 py-2 text-sm"
    type.to_s == "alert" ? "#{base} bg-red-50 text-red-700 border border-red-200" : "#{base} bg-green-50 text-green-700 border border-green-200"
  end
end
