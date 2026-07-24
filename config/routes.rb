Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]

  root "dashboard#show"
  resource :dashboard, only: :show, controller: "dashboard"
  resources :habits
  resources :completions, only: :create

  get "up" => "rails/health#show", as: :rails_health_check

  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
