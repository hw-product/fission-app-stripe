class StripeController < ApplicationController

  before_action :validate_user!, :only => []
  before_action :validate_access!, :only => []

  def pricing
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to default_url
      end
      format.html do
        if(isolated_product?)
          products = [@product.internal_name]
        else
          products = Product.all.map(&:internal_name)
        end
        @plans = Plan.order(:name).all.find_all do |plan|
          (plan.products & products).empty?
        end.sort_by(&:generated_cost)
        @plans.map! do |plan|
          result = Smash.new(:instance => plan)
          if(plan.description.present?)
            result[:description] = Kramdown::Document.new(plan.description).
              to_html.html_safe
          end
          result
        end
        @plans
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
