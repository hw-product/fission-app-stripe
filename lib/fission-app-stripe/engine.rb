module FissionApp
  module Stripe
    class Engine < ::Rails::Engine

      config.to_prepare do |config|
        require 'stripe'
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

    end
  end
end
