ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

ENV["WHATSAPP_APP_SECRET"] = "test-app-secret"
ENV["WHATSAPP_VERIFY_TOKEN"] = "test-verify-token"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include DraftHelper

    def create_merchant(name: "Cave du Coin", city: "Lyon", phone: "+33612345678")
      Merchant.create!(name: name, city: city).tap do |merchant|
        merchant.phone_numbers.create!(number: phone, primary: true)
      end
    end
  end
end
