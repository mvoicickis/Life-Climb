Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]

  root "pages#home"
  resource :dashboard, only: :show, controller: "dashboard"
  resource :life_map, only: :show, controller: "life_maps"
  resource :missions, only: :show, controller: "missions"
  resource :settings, only: %i[ show update ]
  patch "settings/reorder", to: "settings#reorder", as: :reorder_settings
  patch "settings/habits/:id", to: "settings#update_habit", as: :settings_habit
  resource :life_area_selections, only: %i[ show update ], controller: "life_area_selections"
  resource :v2_onboarding, only: %i[ show update ], controller: "v2_onboardings"
  resources :life_journeys, only: %i[ new create show ]
  resource :focus, only: %i[ show update ], controller: "focus"
  post "missions/:mission_id/complete", to: "mission_completions#create", as: :mission_completion

  resource :onboarding, only: %i[ show update ], controller: "onboarding"
  resources :life_areas, only: %i[ show update ] do
    member do
      post :focus
      post :closer
    end
  end
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
  resource :support, only: :show, controller: "supports"
  post "support/dismiss", to: "supports#dismiss_moment", as: :dismiss_support_moment
  resource :about, only: :show, controller: "abouts"

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
