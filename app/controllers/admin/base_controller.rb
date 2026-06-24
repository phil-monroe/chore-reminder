# Common parent for the caregiver-facing admin area (see CLAUDE.md
# "Authentication" - this app has no per-user accounts, just one shared
# password). Gates every Admin:: controller behind an authenticated session
# via a before_action, rather than the Rack middleware this used to be -
# GoodJob's mounted dashboard at /admin/good_job has its own controllers that
# don't inherit from this (or from ApplicationController at all), so it's
# gated separately by a routing constraint instead (see
# AdminSessionConstraint, config/routes.rb).
class Admin::BaseController < ApplicationController
  SESSION_KEY = :admin_authenticated

  before_action :require_authenticated!

  private

  def require_authenticated!
    redirect_to login_path unless session[SESSION_KEY]
  end
end
