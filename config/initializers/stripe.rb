unless(defined?(Rake))
  require 'stripe'

  if(ENV['STRIPE_SECRET_KEY'] && ENV['STRIPE_PUBLISHABLE_KEY'])
    Rails.application.config.stripe_publish_key = ENV['STRIPE_PUBLISHABLE_KEY']
    Stripe.api_key = ENV['STRIPE_SECRET_KEY']
  else
    raise 'Failed to configure stripe! Ensure STRIPE_SECRET_KEY and STRIPE_PUBLISHABLE_KEY environment variables are set!'
  end
end
