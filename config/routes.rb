Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"

  # Protected by the site-wide HTTP Basic Auth middleware (see CLAUDE.md)
  # along with everything else.
  mount GoodJob::Engine => "good_job"

  # Excluded from the site-wide Basic Auth middleware (see
  # app/middleware/basic_auth_skip_health_check.rb) since Twilio can't supply
  # those credentials; authenticated instead via Twilio's request signature.
  post "integrations/twilio/sms_inbound_webhook", to: "integrations/twilio#sms_inbound_webhook", as: :twilio_sms_inbound_webhook

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
    end
  end
end
