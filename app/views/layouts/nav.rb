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
      link_to "Dashboard", admin_root_path, class: LINK_CLASS
      link_to "Connected apps", admin_oauth_clients_path, class: LINK_CLASS
    end

    link_to "Help", help_path, class: "#{LINK_CLASS} ml-auto"

    if admin_authenticated?
      button_to "Logout", logout_path, method: :delete, class: "#{LINK_CLASS} bg-transparent border-none p-0 cursor-pointer"
    else
      link_to "Login", login_path, class: LINK_CLASS
    end
  end
end
