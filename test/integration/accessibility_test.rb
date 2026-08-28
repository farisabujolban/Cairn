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

  # §7: validation errors are associated to their input via aria-describedby.
  # Without the association a screen reader reads "Title, edit text, invalid"
  # and never reaches the sentence saying what was actually wrong with it.
  test "a validation error is tied to the input it belongs to" do
    post project_epics_url(projects(:apollo)), params: { epic: { title: "", status: "backlog" } }

    assert_response :unprocessable_content

    input = css_select("#epic_title").sole
    assert_equal "true", input["aria-invalid"]
    assert_select "##{input["aria-describedby"]}", text: /can't be blank/i
  end

  # The wiring must appear only where there is something to announce: a
  # describedby pointing at an element that was not rendered is a dangling
  # reference, which some screen readers read as nothing at all.
  test "a valid input carries no error wiring" do
    get new_project_epic_url(projects(:apollo))

    input = css_select("#epic_title").sole
    assert_nil input["aria-describedby"]
    assert_nil input["aria-invalid"]
  end

  # Every control needs a name, and a placeholder or a nearby heading is not
  # one. Walked across every form screen rather than asserted per form, so a
  # form added later is covered without anyone remembering to add a test.
  test "every control on every project form is labelled" do
    project = projects(:apollo)
    epic = epics(:launch)

    [ new_project_epic_path(project), edit_project_epic_path(project, epic),
      new_project_milestone_path(project), edit_project_milestone_path(project, milestones(:v1)),
      new_project_epic_story_path(project, epic), edit_project_story_path(project, stories(:countdown)),
      new_project_story_task_path(project, stories(:countdown)), edit_project_task_path(project, tasks(:wire_the_clock)),
      new_project_membership_path(project), project_memberships_path(project),
      edit_project_path(project) ].each do |path|
      get path

      assert_response :success, "expected #{path} to render"
      assert_empty unlabelled_controls, "#{path} has controls with no accessible name"
    end
  end

  # The sign-in and password forms are the app's front door and were generated
  # rather than written, so they are the likeliest to have been left out.
  test "every control on the signed-out forms is labelled" do
    sign_out

    [ new_session_path, new_password_path ].each do |path|
      get path

      assert_response :success
      assert_empty unlabelled_controls, "#{path} has controls with no accessible name"
    end
  end

  test "every control on the new project form is labelled" do
    sign_out
    sign_in_as users(:admin)

    get new_project_path

    assert_empty unlabelled_controls
  end

  # The tree renders one status control per row, and Rails derives a field's id
  # from the model name alone — so every epic's select came out as "epic_status"
  # and every sr-only label pointed at the first of them. A screen reader would
  # announce forty controls as "Status for Launch sequence", and clicking any
  # label would focus the wrong row.
  test "every status control in the tree has an id of its own" do
    get project_url(projects(:apollo))

    ids = css_select("select").map { |select| select["id"] }

    assert_operator ids.length, :>, 1, "expected the tree to render several status controls"
    assert_equal ids.uniq, ids, "two status controls share an id"
    assert_equal ids.sort, css_select("label[for]").map { |label| label["for"] }.sort,
                 "a label points at something other than its own control"
  end

  # §7: "style Turbo's existing progress bar. Do not build one." Turbo already
  # shows .turbo-progress-bar on navigation, and the failure mode this guards is
  # someone adding a spinner system beside it that duplicates the framework.
  test "loading indication is Turbo's progress bar, not a second one" do
    stylesheet = File.read(Rails.root.join("app/assets/tailwind/application.css"))

    assert_match(/\.turbo-progress-bar\s*\{/, stylesheet,
                 "Turbo's progress bar is unstyled, so navigation shows the browser default")

    homegrown = Dir[Rails.root.join("app/javascript/**/*.js")].select do |path|
      File.read(path).match?(/spinner|loading[-_ ]?(bar|indicator)/i)
    end
    assert_empty homegrown.map { |p| p.delete_prefix("#{Rails.root}/") },
                 "§7 forbids building a loading indicator beside Turbo's"
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

  private
    # A control is named by a <label for>, or by aria-label / aria-labelledby.
    # Hidden inputs and buttons are excluded: buttons are named by their own
    # text, and a hidden field is not announced at all.
    def unlabelled_controls
      labelled_ids = css_select("label[for]").map { |label| label["for"] }

      css_select("input, select, textarea").reject { |control|
        control["type"].in?(%w[ hidden submit button ]) ||
          control["aria-label"].present? || control["aria-labelledby"].present? ||
          labelled_ids.include?(control["id"])
      }.map { |control| control["name"] || control["id"] || control.to_s }
    end
end
