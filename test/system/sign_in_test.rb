require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  # The whole app is behind sign-in, so this is the flow that must never break:
  # a signed-out visitor asking for a page lands on the form, and signing in
  # returns them to it rather than dumping them at the root.
  test "signing in returns the visitor to the page they asked for" do
    visit project_path(projects(:apollo))

    assert_current_path new_session_path

    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    assert_text projects(:apollo).name
  end

  # The failure path must stay on the form with a message that names neither the
  # email nor the password as the problem.
  test "a wrong password reports a failure that does not say which field was wrong" do
    visit new_session_path

    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "definitely-wrong"
    click_on "Sign in"

    assert_text "Try another email address or password"
    assert_current_path new_session_path
  end

  test "signing out returns the user to the sign-in form" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_text "Projects"

    click_on "Sign out"

    assert_current_path new_session_path
  end
end
