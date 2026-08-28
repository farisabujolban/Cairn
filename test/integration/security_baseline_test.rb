require "test_helper"

class SecurityBaselineTest < ActionDispatch::IntegrationTest
  # Rails sets these by default. They are asserted rather than re-implemented so
  # that a future headers middleware is never written, and so that removing them
  # from default_headers is caught here.
  test "responses carry the default security headers" do
    get new_session_path

    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
    assert_equal "none", response.headers["X-Permitted-Cross-Domain-Policies"]
  end

  # §5 and §13 phase 7. Report-only first: a broken directive then arrives as a
  # report rather than a blank page, and there is still UI work in flight to fix
  # what it surfaces. Phase 8 flips this to enforcing, and the flip is only safe
  # if this phase leaves nothing to report.
  test "a content security policy is sent in report-only mode" do
    get new_session_path

    assert_nil response.headers["Content-Security-Policy"],
               "the policy must not be enforcing yet — §13 flips it in phase 8"
    assert response.headers["Content-Security-Policy-Report-Only"].present?,
           "no report-only policy is being sent"
  end

  # The directives that carry the weight. object-src none kills plugin embedding
  # outright, and script-src without unsafe-inline is the whole point — an
  # injected <script> must not run even if it reaches the page.
  test "the policy locks down scripts, objects and framing" do
    get new_session_path
    policy = response.headers["Content-Security-Policy-Report-Only"]

    assert_includes policy, "object-src 'none'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_includes policy, "base-uri 'self'"
    assert_no_match(/script-src[^;]*'unsafe-inline'/, policy,
                    "unsafe-inline in script-src would defeat the policy")
    assert_no_match(/script-src[^;]*'unsafe-eval'/, policy)
  end

  # §5 requires nonces rather than unsafe-inline. importmap-rails emits two
  # inline scripts on every page — the importmap itself and the module that
  # boots the app — so without a nonce the app violates its own policy on the
  # first request.
  test "inline scripts carry a nonce that the policy names" do
    get new_session_path
    policy = response.headers["Content-Security-Policy-Report-Only"]

    nonces = response.body.scan(/<script[^>]*\snonce="([^"]+)"/).flatten
    assert_operator nonces.size, :>=, 2, "importmap's inline scripts are not nonced"
    assert_equal 1, nonces.uniq.size, "one nonce per request, not one per tag"
    assert_includes policy, "'nonce-#{nonces.first}'"
  end

  # A nonce that repeats is a nonce that stored markup can carry. Asserted on the
  # signed-out page because that is where a session-id-derived nonce renders
  # empty — the failure this replaced.
  test "the nonce is different on every response" do
    get new_session_path
    first = response.body[/<script[^>]*\snonce="([^"]+)"/, 1]

    get new_session_path
    second = response.body[/<script[^>]*\snonce="([^"]+)"/, 1]

    assert first.present?, "no nonce on the signed-out page"
    assert_not_equal first, second, "the nonce is stable across requests"
  end

  # The realistic CSRF failure mode is not forgetting to enable protection, it is
  # disabling it to unblock a form and never restoring it. This fails the moment
  # skip_forgery_protection appears anywhere in the codebase.
  test "forgery protection is never skipped anywhere in the app" do
    offenders = Dir[Rails.root.join("app/**/*.rb")].select do |path|
      File.read(path).include?("skip_forgery_protection")
    end

    assert_empty offenders, "skip_forgery_protection is forbidden: #{offenders.inspect}"
  end

  test "forgery protection is enabled" do
    assert ActionController::Base.allow_forgery_protection ||
             Rails.application.config.action_controller.default_protect_from_forgery,
           "expected CSRF protection to be on"
  end

  # permit! is mass assignment with extra steps: here it would let a viewer PATCH
  # a role column. Strong parameters must always name their columns.
  test "no controller uses permit! to bypass strong parameters" do
    offenders = Dir[Rails.root.join("app/controllers/**/*.rb")].select do |path|
      File.read(path).match?(/permit!/)
    end

    assert_empty offenders, "permit! is forbidden: #{offenders.inspect}"
  end

  # User text is never trusted as markup. html_safe or raw on a user-supplied
  # value is the XSS hole ERB's default escaping exists to prevent.
  test "no view marks interpolated content as html_safe" do
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].select do |path|
      File.read(path).match?(/\bhtml_safe\b|<%=\s*raw\b/)
    end

    assert_empty offenders, "html_safe/raw on user content is forbidden: #{offenders.inspect}"
  end

  # Logs go to a server the team now operates, so credentials must never reach
  # them. Checked before the first deploy rather than discovered in a log file.
  test "filter_parameters covers passwords and tokens" do
    filtered = ActiveSupport::ParameterFilter
      .new(Rails.application.config.filter_parameters)
      .filter("password" => "hunter2", "password_confirmation" => "hunter2",
              "token" => "abc123", "secret" => "shhh", "name" => "Ada")

    assert_equal "[FILTERED]", filtered["password"]
    assert_equal "[FILTERED]", filtered["password_confirmation"]
    assert_equal "[FILTERED]", filtered["token"]
    assert_equal "[FILTERED]", filtered["secret"]
    # Non-sensitive params must survive, or the logs become useless for debugging.
    assert_equal "Ada", filtered["name"]
  end

  # CORS grants other origins access to this server. This is a same-origin
  # server-rendered app, so the policy never engages and adding it only creates
  # a way to widen access by accident.
  test "no CORS configuration is present" do
    assert_not File.read(Rails.root.join("Gemfile")).match?(/rack-cors/), "rack-cors must not be added"
    assert_empty Dir[Rails.root.join("config/initializers/*cors*")]
  end
end
