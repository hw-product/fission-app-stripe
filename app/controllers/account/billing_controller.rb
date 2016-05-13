class Account::BillingController < ApplicationController

  before_action :validate_user!, :except => [:order, :upgrade, :downgrade, :modify, :details, :card_delete]
  before_action :validate_access!, :except => [:order, :upgrade, :downgrade, :modify, :details, :card_delete]

  before_action do
    @publish_key = Rails.application.config.stripe_publish_key
  end

  def details
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to account_billing_details_path
      end
      format.html do
        c_payment = @account.customer_payment
        if(c_payment)
          @payment = c_payment.remote_data || Smash.new
          @card = @payment.fetch(:cards, :data, @payment.fetch(:sources, :data, [])).first || {}
          if(c_payment.metadata[:breakdown])
            @line_items = Smash.new(
              :plans => c_payment.metadata[:breakdown].fetch(:plans, Smash.new),
              :pipelines => c_payment.metadata[:breakdown].fetch(:pipelines, Smash.new)
            )
          else
            @line_items = Smash.new(:plans => {}, :pipelines => {})
          end
          @past_due = @payment[:delinquent]
          @can_delete = @line_items.values.all?{|i| i.empty?}
        else
          flash[:error] = 'No payment information exists for this account!'
          redirect_to pricing_path
        end
      end
    end
  end

  def card_delete
    respond_to do |format|
      format.js do
        payment = @account.customer_payment
        stripe_customer = Stripe::Customer.retrieve(@account.customer_payment.customer_id)
        notify!(:card_delete, :payment => payment, :stripe => stripe_customer) do
          stripe_customer.delete
          payment.destroy
        end
        flash[:success] = 'Account payment information has been removed'
        javascript_redirect_to dashboard_path
      end
      format.html do
        flash[:error] = 'Unsupported request!'
        redirect_to account_billing_details_path
      end
    end
  end

  def card_edit
    respond_to do |format|
      format.js do
        payment = @account.customer_payment
        stripe_customer = Stripe::Customer.retrieve(payment.customer_id)
        notify!(:card_edit, :payment => payment, :stripe => stripe_customer) do
          stripe_customer.source = params[:token]
          stripe_customer.save
        end
        flash[:success] = 'New credit card information has been saved!'
        javascript_redirect_to account_billing_details_path
      end
      format.html do
        flash[:error] = 'Unsupported request!'
        redirect_to account_billing_details_path
      end
    end
  end

  def order
    respond_to do |format|
      format.js do
        unless(@account.customer_payment)
          notify!(:account_create) do
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
          end
        end
        javascript_redirect_to account_billing_order_path(:plan_id => params[:plan_id])
      end
      format.html do
        @plan = Plan.find_by_id(params[:plan_id])
        flash[:warn] = "Please confirm new plan order (Plan: #{@plan.name})"
        c_payment = @account.customer_payment
        @payment = c_payment.remote_data
        @card = @payment.fetch(:cards, :data, @payment.fetch(:sources, :data, [])).first || {}
        @line_items = Smash.new(
          :plans => c_payment.metadata.fetch(:breakdown, Smash.new).fetch(:plans, Smash.new),
          :pipelines => c_payment.metadata.fetch(:breakdown, Smash.new).fetch(:pipelines, Smash.new),
          :new_plans => Smash.new(
            @plan.id.to_s => Smash.new(
              :name => @plan.name,
              :cost => @plan.generated_cost(&:integer)
            )
          )
        )
        @past_due = @payment[:delinquent]
        render :details
      end
    end
  end

  def modify
    respond_to do |format|
      format.js do
        desired_plan_ids = [params[:plan_ids]].flatten.compact.uniq
        current_plans = Plan.where(:id => @account.customer_payment.plan_ids).all
        current_plan_ids = current_plans.map(&:id)
        if(desired_plan_ids.map(&:to_s).sort == current_plan_ids.map(&:to_s).sort)
          flash[:warn] = 'No updates detected to apply!'
        else
          stripe_info = stripe_account_information
          desired_plans = Plan.where(:id => desired_plan_ids).all
          notify!(:modify, :plans => desired_plans) do
            set_account_plans(desired_plans, stripe_info)
          end
          flash[:success] = "Subscriptions have been successfully modified!"
        end
        javascript_redirect_to account_billing_details_path
      end
      format.html do
        flash[:error] = 'Unsupported request!'
        redirect_to account_billing_details_path
      end
    end
  end

  protected

  # Load available account stripe information
  #
  # @return [Hash]
  def stripe_account_information
    payment = @account.customer_payment
    stripe_customer = Stripe::Customer.retrieve(@account.customer_payment.customer_id)
    current_stripe_subscription = stripe_customer.subscriptions.all.first
    if(current_stripe_subscription)
      current_stripe_plan = current_stripe_subscription.plan
    end
    Smash.new(
      :payment => payment,
      :customer => stripe_customer,
      :subscription => current_stripe_subscription,
      :plan => current_stripe_plan
    )
  end

  def modify_plan(upgrade_plan, current_plans)
    matching_plans = current_plans.find_all do |c_plan|
      c_plan.product_id == upgrade_plan.product_id
    end
    final_plans = current_plans - matching_plans + [upgrade_plan]
    payment = @account.customer_payment
    stripe_customer = Stripe::Customer.retrieve(@account.customer_payment.customer_id)
    current_stripe_subscription = stripe_customer.subscriptions.all.first
    if(current_stripe_subscription)
      current_stripe_plan = current_stripe_subscription.plan
    end
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
    payment.metadata[:breakdown] ||= Smash.new
    payment.metadata[:breakdown][:plans] = Smash.new.tap do |plns|
      final_plans.each do |plan|
        plns[plan.id.to_s] = {
          :name => plan.name,
          :cost => plan.generated_cost(&:integer)
        }
      end
    end
    payment.save
    if(current_stripe_subscription)
      current_stripe_subscription.plan = stripe_plan.id
      current_stripe_subscription.save
    else
      current_stripe_subscription = stripe_customer.subscriptions.create(:plan => stripe_plan.id)
    end
    begin
      current_stripe_plan.delete if current_stripe_plan
    rescue Stripe::InvalidRequestError => e
      Rails.logger.error "Failed to remove deprecated account plan: #{e.class} - #{e}"
    end
    @plan = upgrade_plan
  end

  def set_account_plans(plans, stripe_info)
    unless(plans.empty?)
      stripe_plan = Stripe::Plan.create(
        :id => SecureRandom.uuid,
        :name => "Heavy Water Products plan for account: #{@account.name}",
        :amount => plans.map{|pln| pln.generated_cost(:integer)}.inject(&:+),
        :currency => 'usd',
        :interval => 'month',
        :trial_period_days => 30,
        :metadata => {
          :fission_account_id => @account.id,
          :fission_plans => plans.map(&:id).map(&:to_s).join(',')
        }
      )
      stripe_info[:payment].metadata[:breakdown] ||= Smash.new
      stripe_info[:payment].metadata[:breakdown][:plans] = Smash.new.tap do |all_plans|
        plans.each do |plan|
          all_plans[plan.id.to_s] = {
            :name => plan.name,
            :cost => plan.generated_cost(&:integer)
          }
        end
      end
      stripe_info[:payment].save
      if(stripe_info[:subscription])
        stripe_info[:subscription].plan = stripe_plan.id
        stripe_info[:subscription].save
      else
        stripe_info[:subscription] = stripe_info[:customer].subscriptions.create(:plan => stripe_plan.id)
      end
      if(stripe_info[:plan])
        begin
          stripe_info[:plan].delete
        rescue Stripe::InvalidRequestError => e
          Rails.logger.error "Failed to remove deprecated account plan: #{e.class} - #{e}"
        end
      end
      stripe_info[:plan] = stripe_plan
    else
      stripe_info[:payment].metadata[:breakdown] ||= Smash.new
      stripe_info[:payment].metadata[:breakdown][:plans] = Smash.new
      stripe_info[:payment].save
      [:subscription, :plan].each do |k|
        if(stripe_info[k])
          stripe_info[k].delete
          stripe_info.delete(k)
        end
      end
    end
    stripe_info
  end

end
