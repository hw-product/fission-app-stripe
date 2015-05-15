Rails.application.routes.draw do
  namespace :account do
    get 'billing', :to => 'billing#display', :as => :billing
  end
  get '/plans', :to => 'stripe#pricing', :as => :pricing
end
