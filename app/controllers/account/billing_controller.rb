class Account::BillingController < ApplicationController

  before_action :validate_user!, :except => [:order, :upgrade, :downgrade]
  before_action :validate_access!, :except => [:order, :upgrade, :downgrade]

  before_action do
    @publish_key = Rails.application.config.stripe_publish_key
  end

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
        if(@account.customer_payment)
          flash[:error] = 'Failed to create payment account. Account already exists!'
        else
          @plan = Plan.find_by_id(params[:plan_id])
          if(@plan)
            stripe_customer = Stripe::Customer.create(
              :description => "Heavy Water Fission account for #{@account.name}",
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
            stripe_plan = Stripe::Plan.create(
              :id => SecureRandom.uuid,
              :name => "#{@product ? @product.name : 'Fission'} plan for account: #{@account.name}",
              :amount => @plan.generated_cost(:integer),
              :currency => 'usd',
              :interval => 'month',
              :metadata => {
                :fission_account_id => @account.id,
                :fission_plans => @plan.id.to_s
              }
            )
            stripe_customer.subscriptions.create(:plan => stripe_plan.id)
            flash[:success] = "Order successfully completed (Plan: #{@plan.name})"
          else
            flash[:error] = 'Failed to locate requested plan!'
          end
        end
        redirect_to dashboard_url
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
        current_plans = Plan.where(:id => @account.customer_payment.plan_ids).all
        upgrade_plan = Plan.find_by_id(params[:plan_id])
        if(upgrade_plan)
          modify_plan(upgrade_plan, current_plans)
          flash[:success] = "Upgrade order successfully completed (Plan: #{@plan.name})"
        else
          flash[:error] = 'Failed to locate requested plan!'
        end
        redirect_to dashboard_url
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
        current_plans = Plan.where(:id => @account.customer_payment.plan_ids).all
        upgrade_plan = Plan.find_by_id(params[:plan_id])
        if(upgrade_plan)
          modify_plan(upgrade_plan, current_plans)
          flash[:warning] = "Downgrade order successfully completed (Plan: #{@plan.name})"
        else
          flash[:error] = 'Failed to locate requested plan!'
        end
        redirect_to dashboard_url
      end
    end
  end

  protected

  def modify_plan(upgrade_plan, current_plans)
    matching_plans = current_plans.find_all do |c_plan|
      c_plan.product_id == upgrade_plan.product_id
    end
    final_plans = current_plans - matching_plans + [upgrade_plan]
    stripe_customer = Stripe::Customer.retrieve(@account.customer_payment.customer_id)
    current_stripe_subscription = stripe_customer.subscriptions.all.first
    current_stripe_plan = current_stripe_subscription.plan
    stripe_plan = Stripe::Plan.create(
      :id => SecureRandom.uuid,
      :name => "Heavy Water Products plan for account: #{@account.name}",
      :amount => final_plans.map{|pln| pln.generated_cost(:integer)}.inject(&:+),
      :currency => 'usd',
      :interval => 'month',
      :metadata => {
        :fission_account_id => @account.id,
        :fission_plans => final_plans.map(&:id).map(&:to_s).join(',')
      }
    )
    current_stripe_subscription.plan = stripe_plan.id
    current_stripe_subscription.save
    begin
      current_stripe_plan.delete
    rescue Stripe::InvalidRequestError => e
      Rails.logger.error "Failed to remove deprecated account plan: #{e.class} - #{e}"
    end
    @plan = upgrade_plan
  end

end
