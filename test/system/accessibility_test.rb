require "application_system_test_case"

# The markup contract for §7 is pinned in test/integration/accessibility_test.rb.
# This is the half that only a real browser can answer: whether the skip link is
# actually reachable, actually visible once it is, and actually moves focus.
# Every one of those can be wrong while the markup looks right.
class AccessibilityTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  # WCAG 2.4.1 end to end. A skip link that renders but sits behind the nav in
  # tab order, or that stays 1px wide when focused, has failed while passing
  # every assertion about its markup.
  test "the first tab reveals the skip link and it moves focus into main" do
    press_tab

    assert_equal "Skip to main content", focused_text
    assert_operator focused_width, :>, 50,
      "the skip link is still collapsed by sr-only when focused, so nobody can see it"

    press_enter

    assert_equal "main", focused_tag,
      "activating the skip link scrolled without moving focus, so the next Tab returns to the nav"
  end

  # Every interactive control has to show where the keyboard is. A control that
  # takes focus invisibly is one a keyboard user has to find by counting.
  test "focused controls draw a visible outline" do
    visit project_path(projects(:apollo))

    press_tab until focused_tag == "a" && focused_text.present?

    assert_not_equal "none", page.evaluate_script(<<~JS)
      getComputedStyle(document.activeElement).outlineStyle
    JS
  end

  private
    def press_tab = page.driver.browser.action.send_keys(:tab).perform

    def press_enter = page.driver.browser.action.send_keys(:enter).perform

    def focused_text = page.evaluate_script("document.activeElement.textContent.trim()")

    def focused_tag = page.evaluate_script("document.activeElement.tagName.toLowerCase()")

    def focused_width = page.evaluate_script("document.activeElement.getBoundingClientRect().width")
end
