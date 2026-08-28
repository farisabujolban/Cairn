require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Kamal's proxy terminates TLS and forwards to this container over plain http.
  # Without this, force_ssl below sees an http request, redirects to https, and
  # the proxy forwards the retry over http again — a redirect loop, not an
  # insecure connection, which is why it is easy to misread.
  config.assume_ssl = true

  # §12. Also what turns on Strict-Transport-Security and the Secure cookie flag,
  # so the session cookie stops being sent over plain http.
  config.force_ssl = true

  # The proxy health-checks /up over http from inside the machine, before any
  # certificate exists. Redirecting that check means the container never reports
  # healthy and the deploy rolls back.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # §5: block DNS rebinding and other Host header attacks. Rails guards this in
  # development and leaves the production list empty, so an unconfigured
  # production app answers to whatever hostname is sent to it.
  #
  # A missing APP_HOST therefore fails the boot rather than defaulting. Assigning
  # an empty list would leave host authorization off with nothing in the log to
  # say so, and a deploy that cannot serve is a better outcome than one that
  # serves anybody's Host header.
  #
  # One host, not a list: it is the same hostname Kamal's proxy is configured
  # with in config/deploy.yml, and one place to change it is worth more than the
  # flexibility of several.
  #
  # The exception is the image build. The Dockerfile runs
  # `bin/rails assets:precompile` under RAILS_ENV=production, which loads this
  # file on a build machine that has no idea where the app will be served — and
  # serves no requests either. Rails marks that build with SECRET_KEY_BASE_DUMMY.
  unless ENV["SECRET_KEY_BASE_DUMMY"]
    config.hosts = [
      ENV.fetch("APP_HOST") do
        raise "APP_HOST is not set. It must be the hostname this app is served " \
              "as — the same one config/deploy.yml gives the proxy. Without it, " \
              "host authorization is off and the app answers to any Host header."
      end
    ]

    # The proxy health-checks /up from inside the machine, by container address,
    # so that one request never carries the app's hostname.
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end
end
