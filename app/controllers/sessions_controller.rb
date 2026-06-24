# Login/logout for the single shared admin password (see CLAUDE.md
# "Authentication" - this app has no per-user accounts). Lives outside the
# /admin namespace, and outside ApplicationController's allow_browser check
# is fine since it inherits it, specifically so its routes (config/routes.rb)
# fall outside AdminSessionGate's "/admin" prefix check and are reachable
# with no session at all - otherwise visiting the login page would itself
# require already being logged in.
class SessionsController < ApplicationController
  def new
    render Views::Sessions::New.new
  end

  def create
    if ActiveSupport::SecurityUtils.secure_compare(params[:password].to_s, ENV.fetch("ADMIN_PASSWORD"))
      session[AdminSessionGate::SESSION_KEY] = true
      redirect_to admin_root_path, notice: "Logged in."
    else
      flash.now[:alert] = "Incorrect password."
      render Views::Sessions::New.new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Logged out."
  end
end
