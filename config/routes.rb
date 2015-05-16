Rails.application.routes.draw do
  namespace :account do
    get 'billing/details', :to => 'billing#display', :as => :billing_details
    post 'billing/order/:plan_id', :to => 'billing#order', :as => :billing_order
    post 'billing/upgrade/:plan_id', :to => 'billing#upgrade', :as => :billing_upgrade
    post 'billing/downgrade/:plan_id', :to => 'billing#downgrade', :as => :billing_downgrade
  end
  get '/plans', :to => 'stripe#pricing', :as => :pricing
end
