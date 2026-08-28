require "application_system_test_case"

# The backlog tree is the app's main working screen, and the two things it does
# that no other screen does — collapsing a branch and changing status in place —
# are both things only a browser can answer. The request tests prove the server
# side; these prove the app.
class BacklogTest < ApplicationSystemTestCase
  setup do
    @project = projects(:apollo)
    @epic = epics(:launch)
    @story = stories(:countdown)

    sign_in_as users(:one)
    visit project_path(@project)
    assert_text "Backlog"
  end

  # §7's key screen, and the reason it exists: every level visible at once,
  # where the rest of the app takes five navigations to reach a task.
  test "the tree shows epics with their stories, and tasks on request" do
    assert_text @epic.title
    assert_text @story.title

    # Tasks start collapsed — they are the detail behind one story, and
    # expanding every one of them buries the shape of the project.
    assert_no_text tasks(:wire_the_clock).title

    click_on "Tasks in #{@story.title}"

    assert_text tasks(:wire_the_clock).title
  end

  # Collapsing has to actually hide the branch, and has to say so to anyone not
  # reading the arrow — aria-expanded is the only thing that does.
  test "collapsing an epic hides its stories and reports the change" do
    toggle = find("button[aria-controls='#{dom_id(@epic, :children)}']")
    assert_equal "true", toggle["aria-expanded"]

    toggle.click

    assert_no_text @story.title
    assert_equal "false", toggle["aria-expanded"]
  end

  # The whole point of inline status: one gesture, no page to leave and come
  # back from. SUGGESTIONS.md records this as the first thing a real user
  # reached for and did not find.
  test "changing a status from the tree saves without leaving the page" do
    within status_control_for(@epic) do
      select "In Progress", from: "Status for #{@epic.title}"
    end

    # Waits for the frame to come back before asking the database, which would
    # otherwise race the request. The selected *attribute* only ever comes from
    # the server — choosing an option in the browser sets the property — so
    # this matches once the swap has actually happened and not before.
    assert_saved_status @epic, "in_progress"

    # No flash and no redirect: the point of the frame is that the page the
    # person was reading is still the page they are reading.
    assert_current_path project_path(@project)
    assert_equal "in_progress", @epic.reload.status
  end

  # A change to one row must not disturb the rest of the tree. Reloading the
  # page here would collapse every branch the person had opened, which is why
  # the response is a frame rather than a redirect.
  test "changing a status leaves an expanded branch expanded" do
    click_on "Tasks in #{@story.title}"
    assert_text tasks(:wire_the_clock).title

    within status_control_for(@story) do
      select "Blocked", from: "Status for #{@story.title}"
    end
    assert_saved_status @story, "blocked"

    # assert rather than assert_text: Capybara reads a second argument as a
    # query type, not as a failure message, and the message is the point here.
    assert page.has_text?(tasks(:wire_the_clock).title),
      "the tree re-rendered and lost the branch the user had opened"
  end

  # A viewer reads the tree and changes nothing in it, so the control is text
  # rather than a select they would be refused on using.
  test "a viewer sees statuses without controls" do
    sign_out
    sign_in_as users(:two)
    visit project_path(@project)

    assert_text @epic.title
    assert_no_selector "select[name='epic[status]']"
  end

  private
    def status_control_for(record) = find("turbo-frame##{dom_id(record, :status)}")

    def assert_saved_status(record, status)
      assert_selector "turbo-frame##{dom_id(record, :status)} option[value=#{status}][selected]"
    end
end
