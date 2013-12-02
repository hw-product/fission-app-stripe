Rails.application.routes.draw do
  scope :orders do
    get '/', :to => 'stripe_controller#index', :as => :order
    get 'new', :to => 'stripe_controller#new', :as => :new_order
    post 'new', :to => 'stripe_controller#create', :as => :create_order
    get 'edit', :to => 'stripe_controller#edit', :as => :edit_order
    post 'edit', :to => 'stripe_controller#update', :as => :update_order
    delete 'destroy', :to => 'stripe_controller#destroy', :as => :destroy_order
    get 'confirmation', :to => 'stripe_controller#confirmation', :as => :order_confirmation
    post 'hook', :to => 'stripe_controller#hook', :as => :order_hook
  end
end
