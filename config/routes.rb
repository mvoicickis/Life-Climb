Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]

  root "pages#home"
  resource :dashboard, only: :show, controller: "dashboard"
  resource :settings, only: %i[ show update ]
  patch "settings/reorder", to: "settings#reorder", as: :reorder_settings
  patch "settings/habits/:id", to: "settings#update_habit", as: :settings_habit

  resource :onboarding, only: %i[ show update ], controller: "onboarding"
  resource :building, only: :show, controller: "buildings"
  resources :buildings, only: [] do
    member do
      post :focus
      post :ship
    end
  end
  resources :today_actions, only: :create do
    member do
      post :complete
    end
  end
  resources :finished_products, only: %i[ index show ]
  resource :life_points, only: :show, controller: "life_points"
  resources :dreams, only: :update
  resources :goals, only: :create

  resources :habits do
    member do
      patch :raise_goal
      patch :decline_goal_raise
    end
  end
  resources :feedbacks, only: %i[ new create ]
  resources :completions, only: :create
  resources :daily_logs, only: :create

  resource :locale, only: :update, controller: "locales"

  namespace :admin do
    root to: "dashboard#show"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
