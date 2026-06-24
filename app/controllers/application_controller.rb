class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :admin_authenticated?

  private

  # Used by Views::Layouts::Nav to render the same nav across authenticated
  # and unauthenticated pages, switching its links based on this. Reads the
  # same session key Admin::BaseController's before_action gates on, so the
  # two never disagree about what "logged in" means.
  def admin_authenticated?
    session[Admin::BaseController::SESSION_KEY].present?
  end
end
