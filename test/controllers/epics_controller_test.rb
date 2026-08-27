require "test_helper"

class EpicsControllerTest < ActionDispatch::IntegrationTest
  # Every epic screen sits behind sign-in, like every other project screen.
  test "redirects a signed-out visitor to sign in" do
    get project_epics_url(projects(:apollo))
    assert_redirected_to new_session_path
  end

  # The listing is the project's own epics in position order — the ordering the
  # backlog tree will reuse in Phase 5.
  test "index lists the project's epics in position order" do
    sign_in_as users(:one)

    get project_epics_url(projects(:apollo))

    assert_response :success
    assert_match(/#{epics(:launch).title}.*#{epics(:telemetry).title}/m, response.body)
  end

  # Containment is per project: another project's epic must not appear here,
  # even for a user who happens to be a member of both.
  test "index excludes epics belonging to another project" do
    sign_in_as users(:one)

    get project_epics_url(projects(:apollo))

    assert_no_match(/#{epics(:gemini_rendezvous).title}/, response.body)
  end

  # 404 rather than 403: the epic list of a project a user is not in must not
  # confirm the project exists.
  test "index returns 404 for a non-member" do
    sign_in_as users(:admin)

    get project_epics_url(projects(:apollo))

    assert_response :not_found
  end

  test "show renders for a viewer" do
    sign_in_as users(:two)

    get project_epic_url(projects(:apollo), epics(:launch))

    assert_response :success
    assert_match epics(:launch).title, response.body
  end

  # Stories are only reachable from the epic that contains them, so the epic
  # page is the one screen that has to offer the way in.
  test "show links to the epic's stories" do
    sign_in_as users(:one)

    get project_epic_url(projects(:apollo), epics(:launch))

    assert_select "a[href=?]", project_epic_stories_path(projects(:apollo), epics(:launch))
  end

  # The lookup runs through the project's own epics, so pairing one project's
  # path with another project's epic id resolves to nothing.
  test "show returns 404 for an epic belonging to a different project" do
    sign_in_as users(:one)

    get project_epic_url(projects(:apollo), epics(:gemini_rendezvous))

    assert_response :not_found
  end

  # Per the §4 matrix, filing epics is member-level work.
  test "create is allowed for a member and appends to the backlog" do
    sign_in_as users(:one)

    assert_difference -> { projects(:gemini).epics.count }, 1 do
      post project_epics_url(projects(:gemini)), params: { epic: { title: "Docking hardware" } }
    end

    epic = projects(:gemini).epics.order(:position).last
    assert_equal "Docking hardware", epic.title
    assert_redirected_to project_epic_url(projects(:gemini), epic)
  end

  # The scheduling axis is set from the same form, so a milestone id must be
  # accepted — but only one belonging to this project.
  test "create accepts a milestone from the same project" do
    sign_in_as users(:one)

    post project_epics_url(projects(:apollo)),
         params: { epic: { title: "Scheduled work", milestone_id: milestones(:v2).id } }

    assert_equal milestones(:v2), Epic.find_by!(title: "Scheduled work").milestone
  end

  # A milestone id from another project is the leak this guards: accepting it
  # would print that milestone's title on a page the user can open.
  test "create rejects a milestone belonging to another project" do
    sign_in_as users(:one)

    assert_no_difference -> { Epic.count } do
      post project_epics_url(projects(:apollo)),
           params: { epic: { title: "Cross-wired", milestone_id: milestones(:gemini_v1).id } }
    end

    assert_response :unprocessable_content
  end

  # "Member" is the floor the matrix draws for changing work, so it is tested
  # with a user who holds exactly that role rather than an owner standing in.
  test "create is allowed for a user whose role is member" do
    sign_in_as apollo_user(:member)

    assert_difference -> { projects(:apollo).epics.count }, 1 do
      post project_epics_url(projects(:apollo)), params: { epic: { title: "Pad hardware" } }
    end
  end

  # The button and the permission behind it are now one question asked of one
  # policy, so a viewer is never offered a control that would only 403.
  test "index hides the new epic button from a viewer and shows it to a member" do
    sign_in_as apollo_user(:viewer)
    get project_epics_url(projects(:apollo))
    assert_select "a[href=?]", new_project_epic_path(projects(:apollo)), count: 0

    sign_in_as apollo_user(:member)
    get project_epics_url(projects(:apollo))
    assert_select "a[href=?]", new_project_epic_path(projects(:apollo))
  end

  test "show hides the edit and delete controls from a viewer" do
    sign_in_as apollo_user(:viewer)

    get project_epic_url(projects(:apollo), epics(:launch))

    assert_select "a[href=?]", edit_project_epic_path(projects(:apollo), epics(:launch)), count: 0
    assert_select "form[action=?]", project_epic_path(projects(:apollo), epics(:launch)), count: 0
  end

  test "new is forbidden for a viewer" do
    sign_in_as users(:two)

    get new_project_epic_url(projects(:apollo))

    assert_response :forbidden
  end

  # A form with no way out is a dead end: the only exit was the browser's back
  # button. Cancel returns to the list the form was opened from.
  test "new offers a cancel link back to the epic list" do
    sign_in_as users(:one)

    get new_project_epic_url(projects(:apollo))

    assert_select "a[href=?]", project_epics_path(projects(:apollo)), text: "Cancel"
  end

  # Cancelling an edit returns to the record being edited, not to the list —
  # that is the screen the Edit button was pressed on.
  test "edit offers a cancel link back to the epic" do
    sign_in_as users(:one)

    get edit_project_epic_url(projects(:apollo), epics(:telemetry))

    assert_select "a[href=?]", project_epic_path(projects(:apollo), epics(:telemetry)), text: "Cancel"
  end

  # A viewer has no create button, but the form is trivially reconstructed by
  # hand — so the check cannot live in the view.
  test "create is forbidden for a viewer" do
    sign_in_as users(:two)

    assert_no_difference -> { Epic.count } do
      post project_epics_url(projects(:apollo)), params: { epic: { title: "Snuck in" } }
    end

    assert_response :forbidden
  end

  test "create re-renders with errors when the epic is invalid" do
    sign_in_as users(:one)

    assert_no_difference -> { Epic.count } do
      post project_epics_url(projects(:apollo)), params: { epic: { title: "" } }
    end

    assert_response :unprocessable_content
  end

  # Mass assignment guard. project_id comes from the path only: a member of one
  # project must not be able to file an epic inside another.
  test "create ignores a project_id smuggled in through the form" do
    sign_in_as users(:one)

    post project_epics_url(projects(:apollo)),
         params: { epic: { title: "Relocated", project_id: projects(:gemini).id } }

    assert_equal projects(:apollo), Epic.find_by!(title: "Relocated").project
  end

  # Status is set manually at every level (§3 rules out rollup), so changing it
  # is an ordinary update rather than a side effect of anything else.
  test "update changes the status for a member" do
    sign_in_as users(:one)

    patch project_epic_url(projects(:apollo), epics(:launch)), params: { epic: { status: "in_progress" } }

    assert_redirected_to project_epic_url(projects(:apollo), epics(:launch))
    assert epics(:launch).reload.in_progress?
  end

  # The direct-PATCH case from §4: a viewer bypassing the UI entirely.
  test "update is forbidden for a viewer" do
    sign_in_as users(:two)

    patch project_epic_url(projects(:apollo), epics(:launch)), params: { epic: { title: "Vandalised" } }

    assert_response :forbidden
    assert_not_equal "Vandalised", epics(:launch).reload.title
  end

  test "destroy removes the epic for a member" do
    sign_in_as users(:one)

    assert_difference -> { Epic.count }, -1 do
      delete project_epic_url(projects(:apollo), epics(:launch))
    end

    assert_redirected_to project_epics_url(projects(:apollo))
  end

  test "destroy is forbidden for a viewer" do
    sign_in_as users(:two)

    assert_no_difference -> { Epic.count } do
      delete project_epic_url(projects(:apollo), epics(:launch))
    end

    assert_response :forbidden
  end

  # A role in one project grants nothing in another, and a non-member gets the
  # same 404 whether the epic exists or not.
  test "destroy returns 404 for a non-member rather than revealing the epic" do
    sign_in_as users(:admin)

    assert_no_difference -> { Epic.count } do
      delete project_epic_url(projects(:apollo), epics(:launch))
    end

    assert_response :not_found
  end
  # §3's progress bar, deferred out of Phase 2 because Epic#progress counts
  # stories and there were none to count.
  test "show reports how many of the epic's stories are done" do
    sign_in_as users(:one)
    stories(:countdown).done!

    get project_epic_url(projects(:apollo), epics(:launch))

    assert_select "[role=progressbar][aria-valuenow=?]", "50"
    assert_select "p", text: "1 of 2 stories done"
  end
end
