class Account::SubscriptionsController < ApplicationController

  before_action :validate_access!, :only => []

  def index
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to account_subscriptions_path(params)
      end
      format.html do
        subscriptions = (fetch_stripe_customer || {}).to_hash.fetch(:subscriptions, {})
        @subscriptions = subscriptions.map do |subscription|
          Smash.new(
            :subscription => subscription,
            :plan => Stripe::Plan.retrieve(subscription[:plan])
          )
        end.sort do |hash|
          hash[:plan].metadata[:fission_product]
        end
      end
    end
  end

  def new
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to default_url
      end
      format.html do
        @customer = fetch_stripe_customer
        if(@customer)
          @current_subscriptions = @customer.subscriptions.map(&:plan)
        else
          @current_subscriptions = []
        end
        if(isolated_product?)
          products = [@product.internal_name]
        else
          products = Product.all.map(&:internal_name)
        end
        @plans = Stripe::Plan.all.to_a.find_all do |plan|
          products.include?(plan[:metadata][:fission_product])
        end.group_by do |plan|
          plan[:metadata][:fission_product]
        end
        @plans.map(&:last).map! do |plans|
          plans.map do |plan|
            result = plan.to_hash
            info = Plan.find_by_remote_id(plan.id)
            if(info)
              result.merge!(info)
              if(result[:description])
                result[:description] = Kramdown::Document.new(result[:description]).
                  to_html.html_safe
              end
            end
            result.with_indifferent_access
          end
        end
      end
    end
  end

  def show
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to account_subscriptions_path(params)
      end
      format.html do
        @subscription = fetch_stripe_customer.subscriptions.retrieve(params[:id])
        @plan = Stripe::Plan.retrieve(@subscription[:plan])
      end
    end
  end

  def create
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javscript_redirect_to account_subscriptions_path
      end
      format.html do
        begin
          customer = fetch_stripe_customer || create_stripe_customer
          # check if updating a subscription or creating new subscription
          # @note this is product based
          current_subscriptions = customer.subscriptions.group_by do |sub|
            Stripe::Plan.retrieve(sub[:plan]).metadata[:fission_product]
          end
          plan = Stripe::Plan.retrieve(params[:plan_id])
          product = plan.metadata[:fission_product]
          if(current_subscriptions[product]) # this is an upgrade
            subscription = current_subscriptions[product]
            old_plan = Stripe::Plan.retrieve(subscription.plan)
            subscription.plan = plan.id
            subscription.save
            flash[:success] = "#{product.humanize}: Subscription updated #{old_plan.name} -> #{plan.name}"
          else # this is a new subscription
            customer.subscriptions.create(:plan => plan.id)
            flash[:success] = "#{product.humanize}: New subscription created! #{plan.name}"
          end
        rescue => e
          flash[:error] = "Failed to apply subscription changes: #{e}"
          Rails.logger.error "Stripe subscription failure: #{e.class}: #{e}"
          Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
        end
        redirect_to account_subscriptions_controller
      end
    end
  end

  def edit
    redirect_url = new_account_subscription_path
    respond_to do |format|
      format.js{ javascript_redirect_to redirect_url }
      format.html{ redirect_to redirect_url }
    end
  end

  def update
    flash[:error] = 'Unsupported request!'
    redirect_url = account_subscriptions_path
    respond_to do |format|
      format.js{ javascript_redirect_to redirect_url }
      format.html{ redirect_to redirect_url }
    end
  end

  def destroy
    begin
      @subscription = fetch_stripe_customer.subscriptions.retrieve(params[:id])
      @subscription.delete
      flash[:success] = "Subscription removed! (#{params[:id]})"
    rescue => e
      flash[:error] = "Failed to delete subscription: #{e}"
      Rails.logger.error "Failed to delete stripe subscription: #{e.class}: #{e}"
      Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
    end
    redirect_url = account_subscriptions_path
    respond_to do |format|
      format.js do
        javascript_redirect_to redirect_url
      end
      format.html do
        redirect_to redirect_url
      end
    end
  end

  protected

  def fetch_stripe_customer
    current_user.run_state.stripe_customers ||= Stripe::Customer.all
    stripe = current_user.run_state.stripe_customers.detect do |customer|
      customer.metadata[:fission_account_id] == current_user.run_state.current_account.id
    end
    if(stripe && params[:stripeToken])
      stripe.card = params[:stripeToken]
      stripe.save
    end
    stripe
  end

  def create_stripe_customer
    Stripe::Customer.create(
      :description => "Fission account for #{@account.name}",
      :metadata => {
        :fission_account_id => current_user.run_state.current_account.id,
        :fission_account_name => current_user.run_state.current_account.name
      },
      :email => params[:stripeEmail],
      :card => params[:stripeToken]
    )
  end

end
