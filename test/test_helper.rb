ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "active_record/testing/query_assertions"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/role_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include RoleTestHelper
    # Lets a test assert that a screen does not query per row. The backlog tree
    # renders three levels at once, so an N+1 there is the difference between
    # one query and hundreds.
    include ActiveRecord::Assertions::QueryAssertions

    # Add more helper methods to be used by all tests here...
  end
end
