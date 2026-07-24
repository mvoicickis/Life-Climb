Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]

  root "dashboard#show"
  resource :dashboard, only: :show, controller: "dashboard"
  resource :settings, only: %i[ show update ]
  patch "settings/reorder", to: "settings#reorder", as: :reorder_settings

  resources :habits
  resources :completions, only: :create
  resources :daily_logs, only: :create

  get "up" => "rails/health#show", as: :rails_health_check
end
