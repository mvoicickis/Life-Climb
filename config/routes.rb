Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]

  root "pages#home"
  resource :dashboard, only: :show, controller: "dashboard"
  resource :settings, only: %i[ show update ]
  patch "settings/reorder", to: "settings#reorder", as: :reorder_settings
  patch "settings/habits/:id", to: "settings#update_habit", as: :settings_habit

  resources :habits do
    member do
      patch :raise_goal
      patch :decline_goal_raise
    end
  end
  resources :feedbacks, only: %i[ new create ]
  resources :completions, only: :create
  resources :daily_logs, only: :create

  namespace :admin do
    root to: "dashboard#show"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
