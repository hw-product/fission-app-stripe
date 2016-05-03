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

        FissionApp.init_product(:fission)
        product = FissionApp.init_product(:billing)
        feature = Fission::Data::Models::ProductFeature.find_or_create(
          :name => 'Account Billing',
          :product_id => product.id
        )
        permission = Fission::Data::Models::Permission.find_or_create(
          :name => 'Account billing access',
          :pattern => '/billing.*'
        )
        unless(feature.permissions.include?(permission))
          feature.add_permission(permission)
        end

        c_b = Rails.application.config.settings.fetch(:callbacks, :before, :dashboard, :summary, Smash.new)
        c_b[:buy_our_stuff!] = lambda do |*_|
          if(current_user.run_state.plans.empty? && current_user.run_state.current_product_features.empty?)
            if(Rails.application.config.settings.fetch(:stripe, :plan_redirect, true))
              redirect_to Rails.application.config.settings.fetch(:stripe, :plan_redirect_path, pricing_path)
            end
          end
        end
        Rails.application.config.settings.set(:callbacks, :before, :dashboard, :summary, c_b)

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
      def fission_account_navigation(product, *_)
        Smash.new(
          'Billing' => Rails.application.routes.url_helpers.account_billing_details_path
        )
      end

      # @return [Array<Fission::Models::Permission>] default permissions
      def default_user_permissions(*_)
        [
          Fission::Data::Models::Permission.new(:pattern => '/billing.*')
        ]
      end

    end
  end
end
