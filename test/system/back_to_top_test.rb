require "application_system_test_case"

# §7's one scroll affordance. The backlog tree is the screen that earns it: a
# project with twenty epics is a long page, and the controls at the top — the
# project's own actions and the section nav — are a long way back.
class BackToTopTest < ApplicationSystemTestCase
  setup do
    @project = projects(:apollo)
    # Enough rows to make the page genuinely scrollable. Without this the button
    # would never cross its threshold and every assertion below would be vacuous.
    25.times { |n| @project.epics.create!(title: "Filler epic #{n}", status: :todo) }

    sign_in_as users(:one)
    visit project_path(@project)
    assert_text "Backlog"
  end

  # Hidden at the top of the page, and hidden means gone rather than
  # transparent: a control nobody can see must not be a tab stop either.
  test "the button stays out of the way until the page is scrolled" do
    assert_no_selector "[data-testid=back-to-top]", visible: true
    assert_equal 0, tab_stops_matching("back-to-top"),
      "an invisible button is still in the tab order"
  end

  test "the button appears past the threshold and returns to the top" do
    scroll_to_bottom

    assert_selector "[data-testid=back-to-top]", visible: true
    assert_operator scroll_position, :>, 0

    find("[data-testid=back-to-top]").click

    # Capybara has no wait for a scroll position, and a smooth scroll takes time
    # to land, so this polls rather than asserting on the instant after a click.
    assert_scrolled_to_top
  end

  # Scrolling back up past the threshold should put it away again, or it becomes
  # permanent furniture over the content.
  test "the button hides again when the page returns to the top" do
    scroll_to_bottom
    assert_selector "[data-testid=back-to-top]", visible: true

    page.execute_script("window.scrollTo(0, 0)")

    assert_no_selector "[data-testid=back-to-top]", visible: true
  end

  # §7 names the back-to-top scroll specifically as something that must honour
  # prefers-reduced-motion. A JS smooth scroll ignores the CSS scroll-behavior
  # override, so the controller has to ask the media query itself.
  test "the scroll is instant when the visitor asks for reduced motion" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ])

    scroll_to_bottom
    find("[data-testid=back-to-top]").click

    # No polling: with motion reduced the jump is synchronous, so one frame
    # later it must already be home. Polling here would pass on a smooth scroll.
    sleep 0.1
    assert_equal 0, scroll_position,
      "the scroll animated despite prefers-reduced-motion: reduce"
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  private
    def scroll_to_bottom
      page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
      assert_operator scroll_position, :>, 0
    end

    def scroll_position = page.evaluate_script("Math.round(window.scrollY)")

    def assert_scrolled_to_top
      20.times do
        return if scroll_position.zero?
        sleep 0.1
      end

      flunk "the page never scrolled back to the top (still at #{scroll_position}px)"
    end

    def tab_stops_matching(testid)
      page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("a, button, input, select, textarea"))
             .filter(el => !el.closest("[hidden]") && el.dataset.testid === "#{testid}")
             .length
      JS
    end
end
