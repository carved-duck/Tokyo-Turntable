# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  resources :gigs, only: [ :index, :show, :edit, :update, :destroy ] do
    resources :bookings, only: [ :index, :new, :create, :destroy ]
    resources :attendances, only: [ :create ]
    resources :favorites, only: [:create, :destroy]
  end
  resources :attendances, only: [ :index, :destroy ]

  # root "posts#index"
  resources :venues, only: [ :index, :show, :new, :create ] do
    resources :gigs, only: [ :new, :create ]
  end


  resources :bands, only: [ :index, :show ] do
    resources :bookings, only: [ :index ]
  end

  resources :users, only: [ :show ] do
    collection do
      get :profile, as: :profile
    end
    resources :attendances, only: [ :index ]
  end

  resources :genres, only: [:index]
end
