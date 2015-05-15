module FissionApp
  module Stripe
    class Engine < ::Rails::Engine

      config.to_prepare do |config|
        require 'stripe'
        require 'kramdown'
        if(ENV['STRIPE_SECRET_KEY'] && ENV['STRIPE_PUBLISHABLE_KEY'])
          Rails.application.config.stripe_publish_key = ENV['STRIPE_PUBLISHABLE_KEY']
          ::Stripe.api_key = ENV['STRIPE_SECRET_KEY']
        elsif(Rails.application.config.fission[:stripe])
          Rails.application.config.stripe_publish_key = Rails.application.config.fission.config[:stripe][:publishable_key]
          ::Stripe.api_key = Rails.application.config.fission.config[:stripe][:secret_key]
        else
          Rails.logger.error 'No stripe credentials detected!'
          raise 'Missing stripe credentials!'
        end
        Fission::Data::Models::Product.find_or_create(:name => 'Billing')
      end

      # @return [Array<Fission::Data::Models::Product>]
      def fission_product
        [Fission::Data::Models::Product.find_by_internal_name('billing'),
          Fission::Data::Models::Product.find_by_internal_name('fission')]
      end

      # @return [Hash] navigation
      def fission_navigation(*_)
        Smash.new
      end

      # @return [Hash] account navigation
      def fission_account_navigation(*_)
        Smash.new('Billing' => Rails.application.routes.url_helpers.account_billing_path)
      end

    end
  end
end
