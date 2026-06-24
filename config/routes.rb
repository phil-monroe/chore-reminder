Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Unauthenticated marketing/help pages (PagesController) - "/" is a
  # high-level features overview, "/help" a how-to knowledge base. Both
  # render FEATURES.md/HOW_TO.md from the repo root. Logging into the
  # admin area itself is still reached via the "Login" link these pages
  # render, which redirects to the login form below if not yet authenticated.
  root to: "pages#home"
  get "help", to: "pages#help", as: :help

  # The login form for the single shared admin password (see CLAUDE.md
  # "Authentication"). Deliberately outside /admin so it's reachable with
  # no session at all - otherwise visiting the login page would itself
  # require already being logged in.
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Excluded from the site-wide admin auth gate since Twilio can't supply
  # session credentials; authenticated instead via Twilio's request signature.
  post "integrations/twilio/sms_inbound_webhook", to: "integrations/twilio#sms_inbound_webhook", as: :twilio_sms_inbound_webhook

  # Everything here is the caregiver-facing admin area. Every Admin::
  # controller inherits from Admin::BaseController, whose before_action
  # gates it behind an authenticated session (see CLAUDE.md "Authentication").
  # Namespaced under /admin so it's cleanly separated from the public,
  # unauthenticated routes below (the health check, the login page, the
  # Twilio webhook, and the per-task public page).
  namespace :admin do
    root "dashboard#index"

    # GoodJob's engine controllers don't inherit from Admin::BaseController
    # (or even ApplicationController), so a before_action can't gate them -
    # this routing constraint checks the same session flag at the routing
    # layer instead (see AdminSessionConstraint). A failed constraint just
    # 404s rather than redirecting, hence the catch-all redirect below.
    mount GoodJob::Engine, at: "good_job", constraints: AdminSessionConstraint.new

    resources :users do
      resources :tasks do
        member do
          patch :move_higher
          patch :move_lower
          patch :toggle_done
        end
      end

      resources :task_definitions do
        member do
          post :generate_now
        end
      end

      resources :reminder_definitions do
        member do
          post :send_now
        end
      end

      member do
        get :new_message
        post :send_message
        post :send_welcome_message
        get :conversation
        post :send_inbound_message
      end
    end
  end

  # AdminSessionConstraint above just fails to match for an unauthenticated
  # visitor, which alone would 404 (no other route matches) rather than send
  # them to the login page like every other unauthenticated /admin/... request
  # gets via Admin::BaseController. This catches that case for GoodJob's
  # mounted engine specifically.
  match "/admin/good_job(/*path)", to: redirect("/login"), via: :all

  # The unauthenticated page linked from reminder texts (see Task#link_url) -
  # household members tap this from their phone with no session
  # credentials, so it's excluded from the site-wide auth gate and kept outside
  # /admin/... entirely so it never collides with the admin routes above
  # (which are matched first regardless, since routes are tried in
  # declaration order). Constrained to the same charset
  # User#username/TaskDefinition#slug are generated with (plus bare digits,
  # since both fall back to their numeric id) so it doesn't swallow
  # unrelated two-segment requests.
  get "/:username/:task_definition_slug", to: "public/task_definitions#show", as: :public_task_definition,
    constraints: {username: /[a-z0-9_-]+/, task_definition_slug: /[a-z0-9_-]+/}
end
