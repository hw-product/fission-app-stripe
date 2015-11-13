Rails.application.routes.draw do
  namespace :account do
    get 'billing/details', :to => 'billing#details', :as => :billing_details
    post 'billing/modify', :to => 'billing#modify_existing', :as => :billing_modify
    post 'billing/card/edit', :to => 'billing#card_edit', :as => :billing_edit
    post 'billing/order/:plan_id', :to => 'billing#order', :as => :billing_order
    post 'billing/upgrade/:plan_id', :to => 'billing#upgrade', :as => :billing_upgrade
    post 'billing/downgrade/:plan_id', :to => 'billing#downgrade', :as => :billing_downgrade
  end
  get '/plans', :to => 'stripe#pricing', :as => :pricing
end
