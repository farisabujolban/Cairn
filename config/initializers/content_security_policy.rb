# Be sure to restart your server when you modify this file.

# §5's CSP. Rolled out report-only in phase 7 and enforcing since phase 8.
#
# Report-only first was deliberate: a directive that is too strict arrives as a
# console report rather than as a blank page, and phase 7 still had UI work in
# flight to fix whatever it surfaced. The flip was only safe because nothing was
# left reporting — test/system/content_security_policy_test.rb loads every screen
# in a real browser and fails if it reports a single violation.
#
# That test is what keeps this enforcing safely, and it is why a new screen is
# not finished until it has been added to the list there. Under enforcement a
# violation is no longer a line in a console: it is a script that does not run
# or a stylesheet that does not apply, on a page that otherwise looks fine.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self
    policy.img_src     :self, :data
    policy.object_src  :none

    # No :https alongside :self. This app loads nothing from anywhere else, and
    # :https would permit script from any host that happens to serve TLS —
    # which is most of the internet, and defeats the directive.
    policy.script_src  :self
    policy.style_src   :self

    # tailwindcss-rails compiles to a real stylesheet, so no unsafe-inline is
    # needed for <style> blocks. Style *attributes* are a separate directive and
    # are handled below.
    policy.connect_src :self
    policy.base_uri    :self
    policy.form_action :self

    # frame-ancestors, not X-Frame-Options: it is the modern control and the one
    # browsers consult when both are present.
    policy.frame_ancestors :none
  end

  # §5: nonces rather than unsafe-inline. importmap-rails emits two inline
  # scripts on every page — the importmap and the module that boots the app —
  # and without a nonce the app violates its own policy on the first request.
  #
  # Random per response, deliberately NOT request.session.id, which is what
  # Rails' generated comment suggests. Two reasons:
  #
  #   1. A signed-out request has no session id, so the nonce renders empty. The
  #      policy then reads script-src 'self' 'nonce-' and every script carries
  #      nonce="" — the mechanism silently does nothing on the sign-in page,
  #      which is the one page every user meets and the only one reachable
  #      without credentials.
  #
  #   2. A session-scoped nonce is the same value on every page for as long as
  #      someone stays signed in. A nonce's whole job is to be unguessable per
  #      response: stored markup written once with a valid nonce would keep
  #      executing on later page loads. Per-response randomness is what makes
  #      that impossible.
  #
  # The cost is that HTML bodies differ on every request, so ETag revalidation
  # never returns 304 for pages. That is a few KB on a team-sized app, traded
  # for a nonce that actually holds.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  # style-src as well as script-src. Turbo injects a <style> element at runtime
  # for its progress bar and takes the nonce from the csp-nonce meta tag the
  # layout renders; without style-src here that nonce is not valid for a style
  # element, and every page reports a style-src-elem violation.
  config.content_security_policy_nonce_directives = %w[ script-src style-src ]
end
