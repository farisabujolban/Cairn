require "test_helper"

# §7's accessibility items, pinned at the markup level. They are specified up
# front because the cost is timing, not difficulty: built inline with a template
# they are near-free, and retrofitted they mean reopening every view. These
# tests are what stops a later template quietly opting out.
class AccessibilityTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  # WCAG 2.4.1. The link only works if it is the very first thing focus reaches
  # — a skip link sitting behind three nav links has already failed at the job
  # it exists to do.
  test "the skip link is the first element in the body" do
    get projects_url

    first_element = css_select("body *").first

    assert_equal "a", first_element.name
    assert_equal "#main", first_element["href"]
  end

  # Hidden until it is wanted, visible the moment it is: sr-only alone would
  # leave sighted keyboard users tabbing to a link they cannot see.
  test "the skip link is hidden until it takes focus" do
    get projects_url

    assert_select "a[href='#main'].sr-only.focus\\:not-sr-only"
  end

  # Turbo Drive would otherwise intercept the fragment link and scroll the page
  # itself, skipping the browser step that moves focus to the target. The link
  # then looks like it works and the next Tab returns to the nav. The system
  # test proves the behaviour; this one keeps the attribute from being tidied
  # away by someone who reads it as superstition.
  test "the skip link is left to the browser rather than to Turbo" do
    get projects_url

    assert_select "a[href='#main'][data-turbo=false]"
  end

  # The target has to exist and be unique, or the link scrolls nowhere.
  test "the skip link's target is the one main landmark" do
    get projects_url

    assert_select "main#main", count: 1
  end

  # The sign-in page has no navigation, so a link offering to skip past it would
  # be a keyboard stop that saves nobody anything.
  test "the skip link is absent where there is no navigation to skip" do
    sign_out

    get new_session_url

    assert_select "a[href='#main']", count: 0
    assert_select "main#main", count: 1
  end

  # Real elements rather than divs with roles: assistive technology navigates by
  # landmark, and a div is not one however it is styled.
  test "the page is built from real landmark elements" do
    get projects_url

    assert_select "header", count: 1
    assert_select "header nav", count: 1
    assert_select "main", count: 1
  end

  # §7: "outline: none is forbidden." Removing the focus ring makes the app
  # unusable by keyboard while looking no different to a mouse — the kind of
  # regression nobody notices until somebody cannot work. Grepped rather than
  # rendered, so it catches a template no test happens to visit.
  test "no template or stylesheet removes a focus outline" do
    sources = Dir[Rails.root.join("app/views/**/*.erb")] +
              Dir[Rails.root.join("app/assets/tailwind/**/*.css")]

    offenders = sources.select do |path|
      File.read(path).match?(/outline-none|outline:\s*none/)
    end

    assert_empty offenders.map { |path| path.delete_prefix("#{Rails.root}/") },
                 "§7 forbids removing focus outlines; use a focus-visible: variant instead"
  end

  # The motion-reduce: variants on individual elements say what a template
  # intends, but they rot: the next template forgets one and nothing catches it.
  # A global block is the guarantee underneath them.
  test "the stylesheet honours prefers-reduced-motion globally" do
    stylesheet = File.read(Rails.root.join("app/assets/tailwind/application.css"))

    assert_match(/@media\s*\(prefers-reduced-motion:\s*reduce\)/, stylesheet)
    assert_match(/\*,\s*::before,\s*::after/, stylesheet)
  end
end
