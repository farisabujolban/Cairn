require "test_helper"
require "json"
require "open3"

# §5 and §12 turn on force_ssl, `config.hosts` and an enforcing CSP. Every one of
# those lives in config/environments/production.rb, which **no other test in this
# suite ever loads** — the test environment reads test.rb and nothing else. A
# typo there, or a line left commented out, passes the entire suite and is
# discovered by the first real deploy.
#
# So this boots the production environment for real, in a subprocess, and reads
# the settings back out of it. It is slower than asserting on a string, and it is
# the only version that cannot be fooled: the same file the server will load is
# the file being measured.
#
# SECRET_KEY_BASE stands in for the master key, which is not in the repository
# and not on CI. Nothing in this app reads credentials at boot, so a dummy value
# is enough to get a booted production application.
class ProductionConfigurationTest < ActiveSupport::TestCase
  # One boot per distinct environment, shared by every test that asks for it.
  # Each one costs a couple of seconds.
  @@boots = {}

  # Evaluated inside the booted production app. Predicates are called there
  # rather than marshalled out: config.ssl_options holds a lambda, and the only
  # thing worth asserting about a lambda is what it answers.
  PROBE = <<~'RUBY'.freeze
    request = Struct.new(:path)
    config  = Rails.application.config

    puts "PROBE" + JSON.generate(
      force_ssl:             config.force_ssl,
      assume_ssl:            config.assume_ssl,
      ssl_redirects_up:      !config.ssl_options.dig(:redirect, :exclude)&.call(request.new("/up")),
      ssl_redirects_pages:   !config.ssl_options.dig(:redirect, :exclude)&.call(request.new("/projects")),
      hosts:                 config.hosts.map(&:to_s),
      host_check_skips_up:   !!config.host_authorization&.dig(:exclude)&.call(request.new("/up")),
      csp_report_only:       config.content_security_policy_report_only,
      csp_present:           !config.content_security_policy.nil?
    )
  RUBY

  test "production forces every request over SSL" do
    assert production_config["force_ssl"],
           "force_ssl is what turns on HSTS and Secure cookies (§12)"
  end

  test "production trusts the SSL-terminating proxy in front of it" do
    assert production_config["assume_ssl"],
           "Kamal's proxy terminates TLS and forwards over http, so without " \
           "assume_ssl force_ssl redirects to https forever"
  end

  test "the SSL redirect skips the health check but nothing else" do
    assert_not production_config["ssl_redirects_up"],
               "/up must answer the proxy over http or the container never goes healthy"
    assert production_config["ssl_redirects_pages"],
           "every real page must redirect to https"
  end

  # §5: Rails guards the Host header in development and leaves the production
  # list empty, so an unconfigured production app answers to any hostname sent
  # to it.
  test "production answers only to the host it was deployed as" do
    config = production_config("APP_HOST" => "tracker.example.com")

    assert_equal [ "tracker.example.com" ], config["hosts"]
  end

  test "the host check skips the health check" do
    assert production_config["host_check_skips_up"],
           "the proxy health-checks /up by IP, so that request never carries the app's hostname"
  end

  # The failure this guards against is not a wrong APP_HOST, it is no APP_HOST:
  # config.hosts would be assigned an empty list and host authorization would be
  # off, with nothing in the log to say so. A deploy that cannot serve is a
  # better outcome than one that serves anybody's Host header.
  test "production refuses to boot without a host" do
    _out, err, status = boot_production({})

    assert_not_predicate status, :success?, "production booted with no APP_HOST"
    assert_match(/APP_HOST/, err)
  end

  # The Dockerfile runs bin/rails assets:precompile under RAILS_ENV=production,
  # which loads this same file on a build machine that has no idea where the app
  # will eventually be served. Rails marks that build with SECRET_KEY_BASE_DUMMY.
  # Without this exemption the image cannot be built at all.
  test "the image build boots production without a host" do
    config = production_config("SECRET_KEY_BASE_DUMMY" => "1", "APP_HOST" => nil)

    assert_empty config["hosts"], "an asset build must not pin a hostname it cannot know"
  end

  private
    # APP_HOST is supplied by every caller that expects a booted app, because
    # production refuses to boot without one. The tests about that refusal call
    # boot_production directly.
    def production_config(env = {})
      env = { "APP_HOST" => "tracker.example.com" }.merge(env)

      @@boots[env] ||= begin
        out, err, status = boot_production(env)
        assert_predicate status, :success?, "production would not boot:\n#{err}"
        JSON.parse(out[/^PROBE(\{.*\})$/, 1])
      end
    end

    def boot_production(env)
      Open3.capture3(
        env.merge("RAILS_ENV" => "production", "SECRET_KEY_BASE" => "boot-probe-only"),
        Rails.root.join("bin/rails").to_s, "runner", PROBE
      )
    end
end
