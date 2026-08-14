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

    # Lets a user build more than one destination (root goal) / Plan so tests
    # can cover aggregation, URL switching, and the future Premium mechanic.
    # The default one-destination/one-plan rule stays enforced and has its own
    # coverage (see StrategyGoalOneGoalRuleTest).
    def allow_extra_climbs!(user)
      user.singleton_class.class_eval do
        define_method(:extra_destinations_allowed?) { true }
        define_method(:extra_plans_allowed?) { true }
      end
      user
    end

    # Habits are hidden by default (GameRules.habits_enabled? == false). Tests
    # that exercise the habits-on world call enable_habits! in setup or at the
    # top of the test; the teardown below restores the real default so an
    # enabled test never leaks into the next one.
    def enable_habits!
      GameRules.singleton_class.class_eval { define_method(:habits_enabled?) { true } }
    end
    teardown { GameRules.singleton_class.class_eval { define_method(:habits_enabled?) { false } } }

    # Parallel workers share a process-global I18n.locale. A test that sets
    # :lv/:de (or restores a polluted "previous" locale) can leave the next
    # test asserting English strings against translated copy. Reset every run.
    setup { I18n.locale = I18n.default_locale }
    teardown { I18n.locale = I18n.default_locale }
  end
end
