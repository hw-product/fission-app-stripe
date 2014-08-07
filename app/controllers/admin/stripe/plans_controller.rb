class Admin::Stripe::PlansController < ApplicationController

  before do
    if(params[:id])
      @plan = Stripe::Plan.retrieve(params[:id])
    end
  end

  def index
    @plans = Stripe::Plan.all.find_all do |plan|
      plan[:metadata][:fission_product]
    end.group_by do |plan|
      plan[:metadata][:fission_product]
    end
    @plans.values.each do |plans|
      plans.sort! do |x, y|
        x[:name] <=> y[:name]
      end
    end
    @plans = @plans.values.flatten
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to admin_stripe_plans_path
      end
      format.html
    end
  end

  def new
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to admin_stripe_plans_path
      end
      format.html
    end
  end

  def create
    plan_args = Hash[
      params.map do |key, value|
        if(key.to_s.start_with?('plan_'))
          [key.to_s.sub('plan_', ''), value]
        end
      end.compact
    ]
    plan_args[:metadata] = {
      :fission_product => plan_args.delete(:fission_product)
    }
    begin
      Stripe::Plan.create(plan_args)
      flash[:success] = "New plan has been created! (#{plan_args[:name]})"
    rescue => e
      flash[:error] = "Failed to create plan! (#{plan_args[:name]}): #{e.message}"
      Rails.logger.error "Stripe plan creation failure: #{e.class}: #{e.message}"
      Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
    end
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to admin_stripe_plans_path
      end
      format.html do
        redirect_to admin_stripe_plans_path
      end
    end
  end

  def edit
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to admin_stripe_plans_path
      end
      format.html
    end
  end

  def update
    plan_args = Hash[
      params.map do |key, value|
        if(key.to_s.start_with?('plan_'))
          [key.to_s.sub('plan_', ''), value]
        end
      end.compact
    ]
    plan_args[:metadata] = {
      :fission_product => plan_args.delete(:fission_product)
    }
    begin
      plan_args.each do |key, value|
        @plan.send("#{key}=", value)
      end
      @plan.save
      flash[:success] = "Plan has been updated! (#{plan_args[:name]})"
    rescue => e
      flash[:error] = "Failed to create plan! (#{plan_args[:name]}): #{e.message}"
      Rails.logger.error "Stripe plan creation failure: #{e.class}: #{e.message}"
      Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
    end
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to admin_stripe_plans_path
      end
      format.html do
        redirect_to admin_stripe_plans_path
      end
    end
  end

  def show
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to admin_stripe_plans_path
      end
      format.html
    end
  end

  def destroy
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to admin_stripe_plans_path
      end
      format.html do
        begin
          @plan.delete
        rescue => e
          flash[:error] = "Plan delete failed: #{e.message}"
          Rails.logger.error "Failed to delete stripe plan: #{e.class}: #{e}"
          Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
        end
        redirect_to admin_stripe_plans_path
      end
    end
  end

end
