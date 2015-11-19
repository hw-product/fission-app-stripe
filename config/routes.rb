Rails.application.routes.draw do
  namespace :account do
    get 'billing/details', :to => 'billing#details', :as => :billing_details
    post 'billing/modify', :to => 'billing#modify', :as => :billing_modify
    post 'billing/card/edit', :to => 'billing#card_edit', :as => :billing_edit
    post 'billing/order/:plan_id', :to => 'billing#order', :as => :billing_order
  end
  get '/plans', :to => 'stripe#pricing', :as => :pricing
end
