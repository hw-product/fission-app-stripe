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
      end

      # @return [Array<Fission::Data::Models::Product>]
      def fission_product
        [Fission::Data::Models::Product.find_by_internal_name('fission')]
      end

      # @return [Hash] navigation
      def fission_navigation(*_)
        Smash.new(
          'Stripe' => Smash.new(
            'Subscriptions' => Rails.application.routes.url_for(
              :controller => 'admin/stripe/subscriptions',
              :action => :index,
              :only_path => true
            ),
            'Plans' => Rails.application.routes.url_for(
              :controller => 'admin/stripe/plans',
              :action => :index,
              :only_path => true
            )
          )
        )
      end

    end
  end
end
