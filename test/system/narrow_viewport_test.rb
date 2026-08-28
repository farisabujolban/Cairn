require "application_system_test_case"

# The narrowest realistic phone is where flex layout bugs surface, and no other
# test renders at a width where a row can overflow its card. Two separate
# overflows shipped before this existed: a status column running past the card
# border, and a header button running off the right edge.
#
# The content matters as much as the width. Fixture titles like "v1.1" fit
# anywhere; what broke in practice was a real title beside a spelled-out date,
# so this test writes content of that shape rather than reusing the fixtures.
class NarrowViewportTest < ApplicationSystemTestCase
  # 200 CSS pixels, not 320. A 320px phone has slack: the header button simply
  # shrinks and wraps its own text, and nothing overflows even with the bug
  # present — a test at that width would have passed while the bug shipped. The
  # width that reproduces it is a narrow window at browser zoom, which is how it
  # was found. Chrome clamps its *window* far above this, so the viewport is set
  # through CDP; resize_to would silently give a much wider page and prove
  # nothing.
  #
  # 200 is the assertion, but the layout is kept working at 150. An element's
  # intrinsic minimum width depends on the font, and CI's fonts are wider than
  # macOS's — the backlog tree passed this locally and overflowed by 12px on
  # Linux. Headroom, not the exact number, is what makes this test mean the same
  # thing on both.
  NARROW_WIDTH = 200

  setup do
    @project = projects(:apollo)
    @long_title = "Navigation overhaul and checkout rewrite"

    @project.milestones.create!(title: @long_title, due_on: Date.new(2026, 8, 28),
                                description: "The first milestone of the release")
    @project.epics.create!(title: @long_title, status: :in_progress,
                           description: "Instrument the whole launch sequence end to end")

    sign_in_as users(:one)
    narrow_the_viewport
  end

  test "the milestone list and its header stay inside the viewport" do
    visit project_milestones_path(@project)
    assert_text @long_title

    assert_nothing_overflows "the milestone list"
  end

  test "the epic list and its header stay inside the viewport" do
    visit project_epics_path(@project)
    assert_text @long_title

    assert_nothing_overflows "the epic list"
  end

  # The backlog tree is the hardest case in the app: three levels of indentation
  # eating horizontal space, a status select that cannot shrink below its widest
  # option, and the project's own controls above it. Every one of those pushes
  # right at exactly the width this test renders.
  test "the backlog tree stays inside the viewport at every level" do
    epic = @project.epics.create!(title: @long_title, status: :todo)
    story = epic.stories.create!(title: @long_title, status: :in_progress)
    story.tasks.create!(title: @long_title, status: :blocked)

    visit project_path(@project)
    click_on "Tasks in #{story.title}"
    assert_text @long_title

    assert_nothing_overflows "the backlog tree"
  end

  # The project list gained a status toggle and a Restore button in the same row
  # as the project name, which is the shape that overflowed twice before.
  test "the archived project list stays inside the viewport" do
    @project.update!(name: @long_title)
    @project.archive!

    visit projects_path(status: "archived")
    assert_text @long_title

    assert_nothing_overflows "the archived project list"
  end

  private
    def narrow_the_viewport
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: NARROW_WIDTH, height: 800, deviceScaleFactor: 1, mobile: false)
    end

    # Asserts on every element rather than on the document's scroll width: an
    # element that spills past the right edge is a bug whether or not it happens
    # to make the page scroll, and naming the offender is most of the fix.
    def assert_nothing_overflows(screen)
      worst = page.evaluate_script(<<~JS)
        (() => {
          const viewport = document.documentElement.clientWidth;
          let overflow = 0, offender = "";
          document.querySelectorAll("body *").forEach(element => {
            const over = Math.round(element.getBoundingClientRect().right - viewport);
            if (over > overflow) {
              overflow = over;
              offender = element.tagName.toLowerCase() + "." + String(element.className).slice(0, 60);
            }
          });
          return [ overflow, offender ];
        })()
      JS
      overflow, offender = worst

      assert_operator overflow, :<=, 0,
        "#{screen} spills #{overflow}px past a #{NARROW_WIDTH}px viewport: #{offender}"
    end
end
