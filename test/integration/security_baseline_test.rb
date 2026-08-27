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
