Rails.application.routes.draw do
  namespace :admin do
    namespace :stripe do
      resources :subscriptions
      resources :plans
      resources :customers
      resources :coupons
      resources :discounts
    end
  end
  resources :accounts do
    resources :subscriptions
  end
end
