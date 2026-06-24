# Gates the entire admin namespace (config/routes.rb wraps `namespace :admin`
# in `constraints(AdminSessionConstraint.new) do ... end`) behind the same
# admin session Admin::BaseController checks. Every Admin:: controller
# already enforces this itself via a before_action, but the mounted GoodJob
# dashboard's controllers don't inherit from Admin::BaseController (or
# ApplicationController at all) - only something that runs at the routing
# layer, before any controller, sees every request regardless of which
# engine handles it. Wrapping the whole namespace (rather than just the
# GoodJob mount) keeps the gate uniform and defends against any future
# /admin route that, like GoodJob's, can't go through Admin::BaseController.
#
# A failed constraint just means the route doesn't match, which by itself
# would 404 rather than send an unauthenticated visitor to the login page -
# config/routes.rb adds a catch-all redirect for every /admin/... path to
# cover that.
class AdminSessionConstraint
  def matches?(request)
    request.session[Admin::BaseController::SESSION_KEY].present?
  end
end
