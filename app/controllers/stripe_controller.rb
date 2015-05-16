class StripeController < ApplicationController

  before_action :validate_user!, :only => []
  before_action :validate_access!, :only => []

  before_action do
    @publish_key = Rails.application.config.stripe_publish_key
  end

  def pricing
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to default_url
      end
      format.html do
        if(isolated_product?)
          product_id = @product.id
        end
        @plans = Plan.order(:name).where(:product_id => product_id).all.sort_by(&:generated_cost)
        @plans.map! do |plan|
          result = Smash.new(:instance => plan)
          if(plan.description.present?)
            result[:description] = Kramdown::Document.new(plan.description).
              to_html.html_safe
          end
          result
        end
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

end
