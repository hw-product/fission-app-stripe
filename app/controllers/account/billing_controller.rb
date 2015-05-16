class Accounts::BillingController < ApplicationController

  def details
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        redirect_to dashboard_url
      end
      format.html do

      end
    end
  end

  def order
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        redirect_to dashboard_url
      end
      format.html do
        if(account.customer_payment)
          flash[:error] = 'Failed to create payment account. Account already exists!'
        else
          plan = Plan.find_by_id(params[:plan_id]) # TODO: ERROR when 404
          stripe_customer = Stripe::Customer.create(
            :description => "Heavy Water account for #{@account.name}",
            :metadata => {
              :fission_account_id => @account.id,
              :fission_account_name => @account.name
            },
            :email => params[:stripeEmail],
            :card => params[:stripeToken]
          )
          payment = CustomerPayment.create(
            :account_id => @account.id,
            :customer_id => stripe_customer.id,
            :type => 'stripe'
          )
          plan = Stripe::Plan.create(
            :id => SecureRandom.uuid,
            :name => "#{@product ? @product.name : 'Fission'} plan for account: #{@account.name}",
            :amount => plan.generated_cost(:integer),
            :currency => 'usd',
            :interval => 'month',
            :metadata => {
              :fission_plans => plan.id.to_s
            }
          )
          stripe_customer.subscriptions.create(:plan => plan.id)
          flash[:success] = 'Order successful for THING!'
        end
        redirect_to new_route_url
      end
    end
  end

  def upgrade
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        redirect_to dashboard_url
      end
      format.html do

      end
    end
  end

  def downgrade
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        redirect_to dashboard_url
      end
      format.html do

      end
    end
  end

end
