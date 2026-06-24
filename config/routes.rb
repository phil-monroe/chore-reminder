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
  # "Authentication"). Deliberately outside /admin so AdminSessionGate's
  # path-prefix check never blocks reaching the login page itself.
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Excluded from the site-wide AdminSessionGate middleware (see
  # app/middleware/admin_session_gate.rb) since Twilio can't supply session
  # credentials; authenticated instead via Twilio's request signature.
  post "integrations/twilio/sms_inbound_webhook", to: "integrations/twilio#sms_inbound_webhook", as: :twilio_sms_inbound_webhook

  # Everything here is the caregiver-facing admin area, gated by the
  # site-wide AdminSessionGate middleware (see CLAUDE.md / admin_session_gate.rb,
  # which gates by this exact path prefix). Namespaced under /admin so
  # it's cleanly separated from the public, unauthenticated routes below
  # (the health check, the login page, the Twilio webhook, and the per-task
  # public page).
  namespace :admin do
    root "dashboard#index"

    mount GoodJob::Engine => "good_job"

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

  # The unauthenticated page linked from reminder texts (see Task#link_url) -
  # household members tap this from their phone with no session
  # credentials, so it's excluded from the site-wide auth gate (see
  # app/middleware/admin_session_gate.rb) and kept outside
  # /admin/... entirely so it never collides with the admin routes above
  # (which are matched first regardless, since routes are tried in
  # declaration order). Constrained to the same charset
  # User#username/TaskDefinition#slug are generated with (plus bare digits,
  # since both fall back to their numeric id) so it doesn't swallow
  # unrelated two-segment requests.
  get "/:username/:task_definition_slug", to: "public/task_definitions#show", as: :public_task_definition,
    constraints: {username: /[a-z0-9_-]+/, task_definition_slug: /[a-z0-9_-]+/}
end
