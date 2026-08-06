ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/climb_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ClimbTestHelper

    # Parallel workers share a process-global I18n.locale. A test that sets
    # :lv/:de (or restores a polluted "previous" locale) can leave the next
    # test asserting English strings against translated copy. Reset every run.
    setup { I18n.locale = I18n.default_locale }
    teardown { I18n.locale = I18n.default_locale }
  end
end
