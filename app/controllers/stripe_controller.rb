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
        @plans = Stripe::Plan.all.to_a.find_all do |plan|
          products.include?(plan[:metadata][:fission_product])
        end.group_by do |plan|
          plan[:metadata][:fission_product]
        end
        @plans.map(&:last).map! do |plans|
          plans.map do |plan|
            result = Smash.new(plan.to_hash)
            info = Plan.find_by_remote_id(plan.id)
            if(info)
              result.merge!(info.attributes)
              if(result[:description])
                result[:description] = Kramdown::Document.new(result[:description]).
                  to_html.html_safe
              end
            end
            result
          end
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
