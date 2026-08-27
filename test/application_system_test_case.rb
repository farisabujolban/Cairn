require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Capybara's 2s default is tight for a Turbo form submission round-tripping
  # through headless Chrome: the server answers a sign-in POST in ~260ms (bcrypt),
  # but the browser-side navigation intermittently lands after the deadline, which
  # made these tests fail roughly half the time locally. CI machines are slower
  # still. This is wait budget, not a slow app — a genuine hang fails in 5s.
  Capybara.default_max_wait_time = 5
end
