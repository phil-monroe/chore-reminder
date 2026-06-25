# Shared nav for every page with a header bar (the authenticated admin area,
# the unauthenticated marketing/help pages, and the public per-task page) -
# it switches its links based on admin_authenticated? instead of each page
# hand-rolling its own header for its own auth state. Sessions::New (the
# login screen itself) is the one exception: it's a centered card with no
# link menu at all, not a nav bar, so there's nothing here for it to share.
class Views::Layouts::Nav < Components::Base
  LINK_CLASS = "text-sm text-gray-600 hover:text-gray-900"

  def initialize(container_class: "max-w-3xl mx-auto")
    @container_class = container_class
  end

  def view_template
    nav(class: "bg-white border-b border-gray-200 px-4 py-3") do
      div(class: "#{@container_class} flex items-center gap-4") do
        render_brand
        render_links
      end
    end
  end

  private

  def render_brand
    link_to "Chore Reminder", admin_authenticated? ? admin_root_path : root_path, class: "font-semibold text-gray-900"
  end

  def render_links
    if admin_authenticated?
      div(class: "ml-auto flex items-center gap-4") do
        link_to "Help", help_path, class: LINK_CLASS
        render_account_menu
      end
    else
      link_to "Help", help_path, class: "#{LINK_CLASS} ml-auto"
      link_to "Login", login_path, class: LINK_CLASS
    end
  end

  # Collapses the logged-in-only nav items (Dashboard, Settings, Logout)
  # behind a single "⋯" menu, the same details/summary dropdown pattern as
  # Views::Admin::Users::Show#actions_menu - no JS needed.
  def render_account_menu
    details(class: "relative") do
      summary(class: "list-none [&::-webkit-details-marker]:hidden cursor-pointer bg-white border border-gray-200 rounded-md text-gray-500 hover:text-gray-700 hover:bg-gray-50 text-xl px-3 py-1 leading-none") { plain "⋯" }
      div(class: "absolute right-0 mt-1 w-48 bg-white border border-gray-200 rounded-lg shadow-lg z-10 py-1") do
        menu_link "Dashboard", admin_root_path
        menu_link "Settings", admin_settings_path
        div(class: "border-t border-gray-100 my-1")
        button_to "Logout", logout_path, method: :delete,
          class: "block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 bg-transparent border-0 cursor-pointer"
      end
    end
  end

  def menu_link(text, path)
    link_to text, path, class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
  end
end
