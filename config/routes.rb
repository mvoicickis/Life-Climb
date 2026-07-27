Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]

  root "pages#home"
  resource :dashboard, only: :show, controller: "dashboard"
  resource :life_map, only: :show, controller: "life_maps"
  resource :missions, only: :show, controller: "missions"
  resource :settings, only: %i[ show update ] do
    get "name/edit", to: "settings#edit_name", as: :edit_name, on: :collection
    get "today_count/edit", to: "settings#edit_today_count", as: :edit_today_count, on: :collection
  end
  patch "settings/reorder", to: "settings#reorder", as: :reorder_settings
  patch "settings/habits/:id", to: "settings#update_habit", as: :settings_habit
  resource :life_area_selections, only: %i[ show update ], controller: "life_area_selections"
  resource :v2_onboarding, only: %i[ show update ], controller: "v2_onboardings"
  resources :life_journeys, only: %i[ new create show update ] do
    resource :completion, only: :create, controller: "journey_completions"
    resources :journey_targets, only: %i[ create ]
  end
  resources :strategy_goals, only: %i[ create update destroy ]
  resources :first_climbs, only: :create
  resources :journey_targets, only: %i[ destroy ] do
    member do
      post :log
    end
  end
  resource :next_mountain, only: %i[ show update ], controller: "next_mountains"
  resource :focus, only: %i[ show update ], controller: "focus"
  resource :today_mission, only: :create, controller: "today_missions"
  resources :daily_todos, only: %i[ create destroy ] do
    member do
      post :complete
    end
  end
  resource :battle_completion, only: :create, controller: "battle_completions"
  resources :project_completions, only: :create
  resources :battle_angles, only: :create
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
  resource :strategy_help, only: :create, controller: "strategy_helps"
  resources :completions, only: :create
  resources :daily_logs, only: :create

  resource :locale, only: :update, controller: "locales"

  namespace :developer do
    resource :tools, only: [], controller: "tools" do
      post :restart_new_player_experience
    end
  end

  namespace :admin do
    root to: "dashboard#show"
    resource :statistics, only: :show, controller: "statistics"
    resource :system, only: :show, controller: "systems"
    resource :ops, only: %i[ show update ], controller: "ops"
    resource :strategy, only: %i[ show create ], controller: "strategy"
    resources :feedbacks, only: %i[ index destroy ]
    resources :users, only: %i[ index show edit update destroy ] do
      member do
        patch :promote
        patch :demote
      end
    end
    resources :impersonations, only: %i[ create destroy ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
