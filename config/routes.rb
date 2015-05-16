Rails.application.routes.draw do
  namespace :account do
    get 'billing/details', :to => 'billing#display', :as => :billing_details
    post 'billing/order', :to => 'billing#order', :as => :billing_order
    post 'billing/upgrade', :to => 'billing#upgrade', :as => :billing_upgrade
    post 'billing/downgrade', :to => 'billing#downgrade', :as => :billing_downgrade
  end
  get '/plans', :to => 'stripe#pricing', :as => :pricing
end
