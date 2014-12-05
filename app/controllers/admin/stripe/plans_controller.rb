class Admin::Stripe::PlansController < ApplicationController

  before_action do
    if(params[:id])
      @plan = Stripe::Plan.retrieve(params[:id])
    end
  end

  def index
    @plans = Stripe::Plan.all.to_a.find_all do |plan|
      plan[:metadata][:fission_product]
    end.group_by do |plan|
      plan[:metadata][:fission_product]
    end
    @plans.each do |grouper, plans|
      plans.sort! do |x, y|
        x[:name] <=> y[:name]
      end
    end
    @plans = @plans.map(&:last).flatten
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
      format.html do
        @products = Product.all.map(&:internal_name).sort
      end
    end
  end

  def create
    plan_args = Hash[
      params.map do |key, value|
        if(key.to_s.start_with?('plan_'))
          [key.to_s.sub('plan_', ''), value]
        end
      end.compact
    ].with_indifferent_access
    info_args = Hash[
      params.map do |key, value|
        if(key.to_s.start_with?('info_'))
          [key.to_s.sub('info_', ''), value]
        end
      end.compact
    ].with_indifferent_access
    plan_args[:metadata] = {
      :fission_product => plan_args.delete(:fission_product),
      :fission_product_features => [plan_args.delete(:fission_product_features)].flatten.compact.join(',')
    }
    begin
      plan = Stripe::Plan.create(plan_args)
      Plan.create(info_args.merge(:remote_id => plan.id))
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
      format.html do
        @products = Product.all.map(&:internal_name).sort
        @info = Plan.find_by_remote_id(@plan.id) || {}
      end
    end
  end

  def update
    plan_args = Hash[
      params.map do |key, value|
        if(key.to_s.start_with?('plan_'))
          [key.to_s.sub('plan_', ''), value]
        end
      end.compact
    ].with_indifferent_access
    info_args = Hash[
      params.map do |key, value|
        if(key.to_s.start_with?('info_'))
          [key.to_s.sub('info_', ''), value]
        end
      end.compact
    ].with_indifferent_access
    plan_args[:metadata] = {
      :fission_product => plan_args.delete(:fission_product),
      :fission_product_features => [plan_args.delete(:fission_product_features)].flatten.compact.join(',')
    }
    begin
      plan_args.each do |key, value|
        @plan.send("#{key}=", value)
      end
      @plan.save
      info = Plan.find_by_remote_id(@plan.id) || Plan.new(:remote_id => @plan.id)
      info_args.each do |k,v|
        info.send("#{k}=", v)
      end
      info.save
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
      format.html do
        @info = Plan.find_by_remote_id(@plan.id)
      end
    end
  end

  def destroy
    begin
      @plan.delete
      flash[:success] = "Plan has been deleted (#{@plan.id})"
    rescue => e
      flash[:error] = "Plan delete failed: #{e.message}"
      Rails.logger.error "Failed to delete stripe plan: #{e.class}: #{e}"
      Rails.logger.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
    end
    respond_to do |format|
      format.js do
        javascript_redirect_to admin_stripe_plans_path
      end
      format.html do
        redirect_to admin_stripe_plans_path
      end
    end
  end

  def load_product_features
    respond_to do |format|
      format.js do
        product = Product.find_by_internal_name(params[:plan_fission_product])
        unless(params[:plan_id].blank?)
          @plan = Stripe::Plan.retrieve(params[:plan_id])
          @enabled = @plan[:metadata][:fission_product_features].to_s.split(',').map(&:to_i)
        else
          @enabled = []
        end
        @features = product ? product.product_features : []
      end
      format.html do
        flash[:error] = 'Unsupported request!'
        redirect_to admin_stripe_plans_path
      end
    end
  end

end
