Rails.application.routes.draw do
  namespace :admin do
    resources :plans
  end
  namespace :account do
    resources :subscriptions
  end
  get '/plans', :to => 'stripe#pricing', :as => :pricing
end
