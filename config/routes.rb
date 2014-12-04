Rails.application.routes.draw do
  namespace :admin do
    namespace :stripe do
      resources :subscriptions
      resources :plans do
        collection do
          get :load_product_features
        end
      end
      resources :customers
      resources :coupons
      resources :discounts
    end
  end
  namespace :account do
    resources :subscriptions
  end
  get '/pricing', :to => 'stripe#pricing', :as => :pricing
end
