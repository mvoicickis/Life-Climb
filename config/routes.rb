Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]
  resource :two_factor_session, only: %i[ new create destroy ]

  root "pages#home"
  resource :dashboard, only: :show, controller: "dashboard" do
    resource :quick_battles, only: :create, controller: "dashboard/quick_battles"
  end
  resource :today_commitment, only: [], controller: "today_commitments" do
    patch :level_up
    patch :decline
  end
  resource :today_end_day, only: %i[create destroy], controller: "today_end_days"
  resource :today_eod_acknowledge, only: :create, controller: "today/eod_acknowledges"
  resource :today_plan_tomorrow_battle, only: :create, controller: "today/plan_tomorrow_battles"
  resource :day_shield_tip, only: :destroy
  resource :install_offer, only: %i[ destroy update ]
  resource :life_map, only: :show, controller: "life_maps"
  resource :missions, only: :show, controller: "missions"
  resource :settings, only: %i[ show update ] do
    get "name/edit", to: "settings#edit_name", as: :edit_name, on: :collection
    get "today_count/edit", to: "settings#edit_today_count", as: :edit_today_count, on: :collection
    patch :commitment, action: :update_commitment
  end
  resource :push_config, only: :show, controller: "push_configs"
  resource :push_subscription, only: %i[ create destroy ], controller: "push_subscriptions" do
    post :test
  end
  namespace :notifications do
    resource :quick_add, only: :create, controller: "quick_adds"
    resource :mark_done, only: :create, controller: "mark_dones"
    resource :snooze, only: :create, controller: "snoozes"
    resource :morning_nudge, only: :create, controller: "morning_nudges"
  end
  namespace :settings do
    resource :notifications, only: %i[ show update ], controller: "notifications"
    resource :two_factor, only: %i[ show create destroy ], controller: "two_factors" do
      post :confirm
      post :regenerate_backup_codes
    end
  end
  patch "settings/reorder", to: "settings#reorder", as: :reorder_settings
  patch "settings/habits/:id", to: "settings#update_habit", as: :settings_habit
  resource :life_area_selections, only: %i[ show update ], controller: "life_area_selections"
  resource :v2_onboarding, only: %i[ show update ], controller: "v2_onboardings"
  resource :onboarding_mountain_tour, only: :update, controller: "onboarding_mountain_tours"
  resources :life_journeys, only: %i[ new create show update ] do
    resource :completion, only: :create, controller: "journey_completions"
    resources :journey_targets, only: %i[ create ]
  end
  resources :strategy_goals, only: %i[ create update destroy ] do
    member do
      get :objectives
    end
    resources :practice_tasks, only: %i[ create ]
    resources :habit_links, only: :create, controller: "strategy_goal_habit_links"
    resource :manual_completion, only: %i[ create destroy ], controller: "strategy_goal_completions"
  end
  resources :practice_tasks, only: %i[ update destroy ]
  resources :first_climbs, only: :create
  post "life_journey_plant_destinations", to: "life_journey_plant_destinations#create", as: :life_journey_plant_destinations
  resources :strategy_quantity_logs, only: :create
  resources :strategy_goal_restores, only: :create
  resource :mountain_trail_tour, only: :update, controller: "mountain_trail_tours"
  post "battle_reopens/:id", to: "battle_reopens#create", as: :battle_reopen
  resources :journey_targets, only: %i[ destroy ] do
    member do
      post :log
    end
  end
  resource :next_mountain, only: %i[ show update ], controller: "next_mountains"
  resource :companion_guide, only: %i[ show create ], controller: "companion_guides"
  resource :weekly_planner, only: %i[ show create ], controller: "weekly_planners"
  resource :focus, only: %i[ show update ], controller: "focus"
  resource :today_mission, only: :create, controller: "today_missions"
  resources :daily_todos, only: %i[ create update destroy ] do
    member do
      post :complete
      post :create_step
    end
  end
  resource :battle_completion, only: :create, controller: "battle_completions"
  post "battle_wins/:id", to: "battle_wins#create", as: :battle_win
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
  resource :pricing, only: :show, controller: "pricing"

  namespace :billing do
    post "checkout", to: "checkouts#create"
    post "portal", to: "portals#create"
    post "webhook", to: "webhooks#create"
  end

  resources :areas, only: %i[ index create update destroy ] do
    member do
      patch :move
    end
  end
  resources :habits do
    resources :improvement_projects, only: :create, controller: "habit_improvement_projects"
    member do
      patch :raise_goal
      patch :decline_goal_raise
    end
  end
  resources :feedbacks, only: %i[ new create ]
  resource :strategy_help, only: :create, controller: "strategy_helps"
  resources :completions, only: %i[create destroy]
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

  # Dynamic PWA files from app/views/pwa/* (also linked in application layout)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }
end
