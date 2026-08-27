Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Shallow nesting that keeps the project prefix: collection actions hang off
  # the parent that owns the list, member actions off the project alone. Every
  # path still carries :project_id, which is what ProjectScoped authorizes on,
  # and no URL grows past two levels of nesting.
  resources :projects do
    resources :milestones
    resources :epics do
      resources :stories, only: %i[ index new create ]
    end
    resources :stories, only: %i[ show edit update destroy ]
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "projects#index"
end
