require "test_helper"

# §4 asks for authorization that is impossible to forget rather than merely
# remembered. These two controllers exist only to forget it, so that the guard
# has something to catch — every real controller in the app is written not to
# trip it, which means nothing else in the suite can prove the guard is armed.
class AuthorizationGuardTest < ActionDispatch::IntegrationTest
  class ForgetfulController < ApplicationController
    def show = head(:ok)
  end

  class UnscopedController < ApplicationController
    def index = head(:ok)
  end

  # The whole reason Pundit is wired in at the ApplicationController level. An
  # action that never calls authorize must fail loudly: silently returning 200
  # is how an unauthorized endpoint ships unnoticed.
  #
  # ForgetfulController deliberately has no index action. Pundit's usual
  # `except: :index` form would make this request a bare 404 instead, and the
  # guard would look armed while catching nothing.
  test "an action that never authorizes raises rather than responding" do
    with_routing do |routes|
      routes.draw { get "forgetful" => "authorization_guard_test/forgetful#show" }
      sign_in_as users(:one)

      assert_raises Pundit::AuthorizationNotPerformedError do
        get "/forgetful"
      end
    end
  end

  # The index half of the same guarantee. §4 requires every index to go through
  # a Pundit scope; a bare Model.all would otherwise list every project's rows
  # to anyone signed in, and nothing about the response would look wrong.
  test "an index that never scopes raises rather than responding" do
    with_routing do |routes|
      routes.draw { get "unscoped" => "authorization_guard_test/unscoped#index" }
      sign_in_as users(:one)

      assert_raises Pundit::PolicyScopingNotPerformedError do
        get "/unscoped"
      end
    end
  end

  # The sign-in screens are the one place the guard has to be lifted: there is
  # no signed-in user to hold a role and no project-scoped collection to filter.
  # Pinned here so that lifting it stays a deliberate, visible exception.
  test "the unauthenticated sign-in screens are exempt" do
    get new_session_url
    assert_response :success

    get new_password_url
    assert_response :success
  end
end
