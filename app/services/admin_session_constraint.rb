# Gates the mounted GoodJob dashboard (config/routes.rb's `mount
# GoodJob::Engine`) behind the same admin session Admin::BaseController
# checks. A routing constraint rather than a before_action because GoodJob's
# engine controllers don't inherit from Admin::BaseController (or
# ApplicationController at all) - only something that runs at the routing
# layer, before any controller, sees this request regardless of which
# engine handles it.
#
# A failed constraint just means the route doesn't match, which by itself
# would 404 rather than send an unauthenticated visitor to the login page -
# config/routes.rb adds a catch-all redirect for the engine's path prefix
# to cover that.
class AdminSessionConstraint
  def matches?(request)
    request.session[Admin::BaseController::SESSION_KEY].present?
  end
end
