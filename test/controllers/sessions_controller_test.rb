require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  # Rate limit counters are keyed by IP and outlive a single request, so they are
  # cleared between tests to keep sign-in attempts from leaking across examples.
  setup do
    @user = User.take
    SessionsController.cache_store.clear
  end

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  # A publicly reachable password form without throttling is the most likely way
  # this app gets compromised. The 11th attempt inside the window must be turned
  # away without ever reaching authenticate_by.
  test "throttles sign-in attempts past the rate limit" do
    10.times do
      post session_path, params: { email_address: @user.email_address, password: "wrong" }
      assert_redirected_to new_session_path
    end

    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_equal "Try again later.", flash[:alert]
  end

  # Account enumeration: if an unknown address and a wrong password produce
  # different wording, the login form becomes a directory of who has an account.
  test "reports the same failure for an unknown email and a wrong password" do
    post session_path, params: { email_address: "nobody@example.com", password: "password" }
    unknown_email_alert = flash[:alert]

    post session_path, params: { email_address: @user.email_address, password: "wrong" }
    wrong_password_alert = flash[:alert]

    assert_equal unknown_email_alert, wrong_password_alert
    assert_not_nil unknown_email_alert
  end

  # The other half of the same control: identical wording with non-identical
  # timing still leaks. authenticate_by is what makes the two paths cost the
  # same, so a find_by + authenticate rewrite must fail here.
  test "authenticates through authenticate_by so timing does not reveal the account" do
    assert_match(/User\.authenticate_by/, File.read(Rails.root.join("app/controllers/sessions_controller.rb")))
  end
end
