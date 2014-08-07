class Accounts::SubscriptionsController < ApplicationController

  # @todo fetch account through user filter
  before_action do
    @account = Account.find_by_id(params[:account_id])
  end

  def index
  end

  def new
    respond_to do |format|
      format.js do
        flash[:error] = 'Unsupported request!'
        javascript_redirect_to account_path(param[:account_id])
      end
      format.html do
        @customer = fetch_stripe_customer
        # if(Product.where(:vanity_dns => request.env['SERVER_NAME']))
        #   products = [Product.where(:vanity_dns => request.env['SERVER_NAME']).first.name]
        # else
          products = Product.all.map(&:name)
        # end
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
  end

  def create
  end

  def edit
  end

  def update
  end

  def destroy
  end

  def fetch_stripe_customer
    Stripe::Customer.all.detect do |customer|
      customer.metadata[:fission_account_id] == @account.id
    end
  end
end
