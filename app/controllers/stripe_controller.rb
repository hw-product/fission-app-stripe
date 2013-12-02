class StripeController < ApplicationController

  before_action :validate_user!, :except => [:index]

  before_action do
    @publish_key = Rails.application.config.stripe_publish_key
  end

  def index
    respond_to do |format|
      format.html do
        if(current_user)
          if(current_user.stripe_id)
            redirect_to edit_order_url
          else
            redirect_to new_order_url
          end
        else
          render :partial => :order_form
        end
      end
    end
  end

  def new
    if(current_user.stripe_id)
      respond_to do |format|
        format.html do
          flash[:warning] = 'Account is already registered for payments'
          redirect_to edit_order_path
        end
      end
    else
      respond_to do |format|
        format.html do
          @account = current_user.base_account
          load_packages
          render :partial => :order_form
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
      stripe_customer.update_subscription(:plan => params[:subscription_id], :prorate => true)
      respond_to do |format|
        format.html do
          flash[:success] = 'New subscription was successful!'
          redirect_to edit_order_url
        end
      end
    rescue => e
      Rails.logger.error "Payment registration failed: #{e.class}: #{e}"
      Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      respond_to do |format|
        format.html do
          flash[:error] = 'Failed to register account for payment!'
          redirect_to new_order_url
        end
      end
    end
  end

  def edit
    if(current_user.stripe_id)
      respond_to do |format|
        format.html do
          flash[:warning] = 'Account not registered for payment'
          redirect_to new_order_path
        end
      end
    else
      respond_to do |format|
        format.html do
          @account = current_user.base_account
          @stripe_customer = Stripe::Customer.retrieve(current_user.stripe_id)
          if(@stripe_customer)
            @package = get_package(@stripe_customer.subscription.try(:[], :id))
          end
          load_packages
          render :partial => :order_form
        end
      end
    end
  end

  def update
    begin
      stripe_customer = Stripe::Customer.retrieve(current_user.stripe_id)
      validate_plan!(params[:order][:plan])
      stripe_customer.update_subscription(:plan => params[:order][:plan], :prorate => true)
      respond_to do |format|
        format.html do
          flash[:success] = 'Subscription update successful!'
          redirect_to order_edit_url
        end
      end
    rescue => e
      Rails.logger.error "Payment update failed: #{e.class} - #{e}"
      Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      respond_to do |format|
        format.html do
          flash[:error] = 'Failed to update payment information'
          redirect_to order_edit_url
        end
      end
    end
  end

  def destroy
    respond_to do |format|
      format.html do
        stripe_customer = Stripe::Customer.retrieve(current_user.stripe_id)
        stripe_customer.cancel_subscription
        flash[:warning] = 'Subscription has been canceled!'
        redirect_to root_url
      end
    end
  end

  def confirmation

  protected

  def load_packages
    @packages = JSON.load(File.read(Rails.config.fission_stripe_packages_json))
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

end
