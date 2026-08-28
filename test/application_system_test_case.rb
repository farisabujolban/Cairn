require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Chrome's password manager is switched off, and it is not paranoia.
  #
  # The browser is shared by every test in a run, and Capybara resets cookies
  # between them but not Chrome's own credential store. Once one test signs in
  # successfully, Chrome treats 127.0.0.1 as a site it has a saved password for
  # and starts intervening in the sign-in form: the next test's fill_in on the
  # password field reports success and leaves the field empty. The form then
  # fails HTML5 required validation, the browser refuses to submit, and no
  # request is ever made — which reads as "the flash never appeared" and was the
  # last of this suite's intermittent sign-in failures.
  #
  # The field keeps autocomplete="current-password" in the app, because a real
  # password manager is something users should have. This turns it off in the
  # test browser only.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
    options.add_argument("--disable-features=PasswordManagerEnabled,AutofillServerCommunication,PasswordLeakDetection")
  end

  # Capybara's 2s default is tight for a Turbo form submission round-tripping
  # through headless Chrome: the server answers a sign-in POST in ~260ms (bcrypt),
  # but the browser-side navigation intermittently lands after the deadline. CI
  # machines are slower still. This is wait budget, not a slow app — a genuine
  # hang fails in 5s.
  #
  # It is not, however, what the older intermittent sign-in failure was. That was
  # the rate limiter: every test signs in from 127.0.0.1 into a cache store the
  # process shares, and past ten sign-ins the suite throttles itself. test_helper
  # clears the counter between tests.
  Capybara.default_max_wait_time = 5

  # Every system test starts signed in, because the whole app is behind sign-in.
  #
  # Signed in by planting the session cookie rather than by driving the form.
  # Every test that is not about signing in needs an authenticated browser, not
  # a form submission, and paying for the submission on each test made sign-in
  # both the most common step in the suite and its most common flake — a real
  # password check and a Turbo navigation racing Capybara's wait budget, on
  # every test, for no coverage that SignInTest does not already provide.
  #
  # SignInTest still drives the real form. That is where the behaviour belongs,
  # and it is the only place it is now exercised.
  def sign_in_as(user)
    session = user.sessions.create!

    # A cookie needs an origin to attach to, so the browser has to be on the
    # site before it can be given one.
    visit new_session_path
    page.driver.browser.manage.add_cookie(
      name: "session_id", value: signed_session_id(session), path: "/")

    visit root_path
    assert_text "Projects"
  end

  def sign_out
    click_on "Sign out"
    assert_current_path new_session_path
  end

  private
    # The same signing the browser would have received from a real sign-in. The
    # server runs in this process, so it verifies against the same secret.
    def signed_session_id(session)
      jar = ActionDispatch::TestRequest.create.cookie_jar
      jar.signed[:session_id] = session.id
      jar[:session_id]
    end
end
