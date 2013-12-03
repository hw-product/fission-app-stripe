Rails.application.routes.draw do
  scope :orders do
    get '/', :to => 'stripe#index', :as => :order
    get 'new', :to => 'stripe#new', :as => :new_order
    post 'new', :to => 'stripe#create', :as => :create_order
    get 'edit', :to => 'stripe#edit', :as => :edit_order
    post 'edit', :to => 'stripe#update', :as => :update_order
    delete 'destroy', :to => 'stripe#destroy', :as => :destroy_order
    get 'confirmation', :to => 'stripe#confirmation', :as => :order_confirmation
    post 'hook', :to => 'stripe#hook', :as => :order_hook
  end
end
