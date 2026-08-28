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
    # So a test can name a Turbo Frame the way the view names it, rather than
    # hardcoding dom_id's prefix convention and drifting from it.
    include ActionView::RecordIdentifier

    # The sign-in rate limiter counts attempts per IP in a cache store the whole
    # test process shares, and every test signs in from 127.0.0.1. Left alone, a
    # suite that signs in more than ten times within three minutes starts
    # rate-limiting itself — which is what the "intermittent" sign-in failure in
    # the system suite always was, and it gets worse with every test added.
    #
    # Cleared per test so the limiter is exercised by the one test that means to
    # (SessionsControllerTest) and by nothing else.
    setup { ActionController::Base.cache_store.clear }

    # Add more helper methods to be used by all tests here...
  end
end
