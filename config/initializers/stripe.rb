require 'stripe'

Rails.application.config.fission_packages_json = ENV.fetch(
  'FISSION_PACKAGES_JSON', File.join(File.dirname(File.dirname(__FILE__)), 'fission_packages.json')
)
