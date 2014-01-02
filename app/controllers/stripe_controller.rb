class StripeController < ApplicationController

  include ActiveSupport::Callbacks

  define_callbacks :subscribed

  before_action :set_keys
  before_action :validate_user!, :except => [:index]

  before_action do
    @account = Account[params[:account_id]]
    unless(@account.owner == current_user || @account.owners.include?(current_user))
      raise "You don't own me!"
    end
    @publish_key = Rails.application.config.stripe_publish_key
    @layout_freeform = true
  end

  def show
    respond_to do |format|
      format.html do
        if(current_user)
          if(current_user.base_account.stripe_id)
            redirect_to edit_account_order_url(@account)
          else
            redirect_to new_account_order_url(@account)
          end
        else
          load_packages
          render 'stripe/order_form'
        end
      end
    end
  end

  def new
    if(@account.stripe_id)
      respond_to do |format|
        format.html do
          flash[:warning] = 'Account is already registered for payments'
          redirect_to edit_order_path(@account)
        end
      end
    else
      respond_to do |format|
        format.html do
          load_packages
          render 'stripe/order_form'
        end
      end
    end
  end

  def create
    begin
      user = current_user
      account = user.base_account
      stripe_customer = Stripe::Customer.create(
        :description => "#{account.name} Fission account",
        :metadata => {
          :fission_account_id => account.id
        }
      )
      account.stripe_id = stripe_customer[:id]
      unless(account.save)
        raise "Failed to save account! #{account.errors.join(', ')}"
      end
      validate_plan!(params[:subscription_id])
      run_callback :subscribed do
        stripe_customer.update_subscription(:plan => params[:subscription_id], :prorate => true)
        respond_to do |format|
          format.html do
            flash[:success] = 'New subscription was successful!'
            redirect_to root_url
          end
        end
      end
    rescue => e
      Rails.logger.error "Payment registration failed: #{e.class}: #{e}"
      Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      respond_to do |format|
        format.html do
          flash[:error] = 'Failed to register account for payment!'
          redirect_to new_account_order_url(@account)
        end
      end
    end
  end

  def edit
    if(current_user.base_account.stripe_id)
      respond_to do |format|
        format.html do
          flash[:warning] = 'Account not registered for payment'
          redirect_to new_account_order_path(@account)
        end
      end
    else
      respond_to do |format|
        format.html do
          @account = current_user.base_account
          @stripe_customer = Stripe::Customer.retrieve(current_user.base_account.stripe_id)
          if(@stripe_customer)
            @package = get_package(@stripe_customer.subscription.try(:[], :id))
          end
          load_packages
          render 'stripe/order_form'
        end
      end
    end
  end

  def update
    begin
      stripe_customer = Stripe::Customer.retrieve(current_user.base_account.stripe_id)
      validate_plan!(params[:order][:plan])
      stripe_customer.update_subscription(:plan => params[:order][:plan], :prorate => true)
      respond_to do |format|
        format.html do
          flash[:success] = 'Subscription update successful!'
          redirect_to order_edit_url(@account)
        end
      end
    rescue => e
      Rails.logger.error "Payment update failed: #{e.class} - #{e}"
      Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      respond_to do |format|
        format.html do
          flash[:error] = 'Failed to update payment information'
          redirect_to order_edit_url(@account)
        end
      end
    end
  end

  def destroy
    respond_to do |format|
      format.html do
        stripe_customer = Stripe::Customer.retrieve(current_user.base_account.stripe_id)
        stripe_customer.cancel_subscription
        flash[:warning] = 'Subscription has been canceled!'
        redirect_to root_url
      end
    end
  end

  def hook
    respond_to do |format|
      format.json do
        event = Stripe::Event.retrieve(params[:id])
        # do stuff
        head :ok
      end
    end
  end

  protected

  # TODO: How are we identifying pricing to display?
  def load_packages
    @packages = Rails.application.config.fission.pricing[:packager]
  end

  def get_packages(pkg_id)
    load_packages.detect do |pkg|
      pkg['id'] == pkg_id
    end
  end

  def validate_plan!(plan_id)
    unless(get_packages(plan_id))
      raise 'ACK: BAD SUBSCRIPTION ID!'
    end
  end

  def set_keys
    if(ENV['STRIPE_SECRET_KEY'] && ENV['STRIPE_PUBLISHABLE_KEY'])
      Rails.application.config.stripe_publish_key = ENV['STRIPE_PUBLISHABLE_KEY']
      Stripe.api_key = ENV['STRIPE_SECRET_KEY']
    elsif(Rails.application.config.fission[:stripe])
      Rails.application.config.stripe_publish_key = Rails.application.config.fission.config[:stripe][:publishable_key]
      Stripe.api_key = Rails.application.config.fission.config[:stripe][:secret_key]
    else
      Rails.logger.error 'No stripe credentials detected!'
      raise 'Missing credentials'
    end
  end

end
