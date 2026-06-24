# Login/logout for the single shared admin password (see CLAUDE.md
# "Authentication" - this app has no per-user accounts). Lives outside the
# /admin namespace (config/routes.rb), unlike every Admin:: controller, so
# it's reachable with no session at all - otherwise visiting the login page
# would itself require already being logged in.
class SessionsController < ApplicationController
  def new
    if session[Admin::BaseController::SESSION_KEY]
      redirect_to post_login_redirect_path
    else
      render Views::Sessions::New.new
    end
  end

  def create
    if ActiveSupport::SecurityUtils.secure_compare(params[:password].to_s, ENV.fetch("ADMIN_PASSWORD"))
      session[Admin::BaseController::SESSION_KEY] = true
      redirect_to post_login_redirect_path, notice: "Logged in."
    else
      flash.now[:alert] = "Incorrect password."
      render Views::Sessions::New.new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Logged out."
  end

  private

  # Oauth::AuthorizationsController stashes its own URL here before sending
  # an unauthenticated caregiver to /login (see "MCP server" in CLAUDE.md),
  # so logging in resumes the OAuth flow instead of dropping them on the
  # admin dashboard. Restricted to /oauth/authorize so this can't be used as
  # an open redirect via a tampered session.
  def post_login_redirect_path
    return_to = session.delete(:return_to_after_login)
    (return_to.present? && return_to.start_with?("/oauth/authorize")) ? return_to : admin_root_path
  end
end
