Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # 訪問者側のルート
  root "employees#index"
  
  resources :employees, only: [:index]
  resources :visits, only: [:new, :create] do
    member do
      get :status
    end
  end
  get "complete", to: "visits#complete"

  # Slack webhook
  post "slack/actions", to: "slack_actions#create"

  # 管理画面
  namespace :admin do
    root to: "employees#index"
    
    # 認証
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"
    
    # 従業員管理
    resources :employees
    
    # 部署管理
    resources :departments
    
    # SmartHR同期
    resource :smarthr_sync, only: [:create, :show]
  end
end
