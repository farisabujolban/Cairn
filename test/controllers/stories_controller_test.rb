require "test_helper"

class StoriesControllerTest < ActionDispatch::IntegrationTest
  # Every story screen sits behind sign-in, like every other project screen.
  test "redirects a signed-out visitor to sign in" do
    get project_epic_stories_url(projects(:apollo), epics(:launch))
    assert_redirected_to new_session_path
  end

  # The listing is one epic's own stories in position order — the ordering the
  # backlog tree will reuse in Phase 5.
  test "index lists the epic's stories in position order" do
    sign_in_as users(:one)

    get project_epic_stories_url(projects(:apollo), epics(:launch))

    assert_response :success
    assert_match(/#{stories(:countdown).title}.*#{stories(:abort_switch).title}/m, response.body)
  end

  # Containment is per epic: a sibling epic's stories belong on that epic's
  # page, not this one.
  test "index excludes stories belonging to another epic" do
    sign_in_as users(:one)

    get project_epic_stories_url(projects(:apollo), epics(:launch))

    assert_no_match(/#{stories(:telemetry_feed).title}/, response.body)
  end

  # 404 rather than 403: the story list of a project a user is not in must not
  # confirm the project exists.
  test "index returns 404 for a non-member" do
    sign_in_as users(:admin)

    get project_epic_stories_url(projects(:apollo), epics(:launch))

    assert_response :not_found
  end

  # The epic is looked up through the project, so pairing one project's path
  # with another project's epic id resolves to nothing.
  test "index returns 404 for an epic belonging to a different project" do
    sign_in_as users(:one)

    get project_epic_stories_url(projects(:apollo), epics(:gemini_rendezvous))

    assert_response :not_found
  end

  test "show renders for a viewer" do
    sign_in_as users(:two)

    get project_story_url(projects(:apollo), stories(:countdown))

    assert_response :success
    assert_match stories(:countdown).title, response.body
  end

  # Tasks are only reachable from the story that contains them, so the story
  # page is the one screen that has to offer the way in.
  test "show links to the story's tasks" do
    sign_in_as users(:one)

    get project_story_url(projects(:apollo), stories(:countdown))

    assert_select "a[href=?]", project_story_tasks_path(projects(:apollo), stories(:countdown))
  end

  # Member routes drop the epic from the path but not the project: the lookup
  # runs through this project's epics, so another project's story is invisible
  # here even to someone who is a member of both.
  test "show returns 404 for a story belonging to a different project" do
    sign_in_as users(:one)

    get project_story_url(projects(:apollo), stories(:gemini_docking))

    assert_response :not_found
  end

  # Per the §4 matrix, filing stories is member-level work.
  test "create is allowed for a member and appends to the epic" do
    sign_in_as users(:one)

    assert_difference -> { epics(:gemini_rendezvous).stories.count }, 1 do
      post project_epic_stories_url(projects(:gemini), epics(:gemini_rendezvous)), params: { story: { title: "Capture ring" } }
    end

    story = epics(:gemini_rendezvous).stories.ordered.last
    assert_equal "Capture ring", story.title
    assert_redirected_to project_story_url(projects(:gemini), story)
  end

  # Scheduling and assignment are set from the same form, so both ids must be
  # accepted — each still checked by the model before it is stored.
  test "create accepts a milestone and an assignee from the same project" do
    sign_in_as users(:one)

    post project_epic_stories_url(projects(:apollo), epics(:launch)),
         params: { story: { title: "Scheduled work", milestone_id: milestones(:v2).id, assignee_id: users(:two).id } }

    story = Story.find_by!(title: "Scheduled work")
    assert_equal milestones(:v2), story.milestone
    assert_equal users(:two), story.assignee
  end

  # The leak this guards: accepting a foreign milestone id would print that
  # milestone's title on a page the user can open.
  test "create rejects a milestone belonging to another project" do
    sign_in_as users(:one)

    assert_no_difference -> { Story.count } do
      post project_epic_stories_url(projects(:apollo), epics(:launch)),
           params: { story: { title: "Cross-wired", milestone_id: milestones(:gemini_v1).id } }
    end

    assert_response :unprocessable_content
  end

  # The same guard on the assignment axis: a non-member cannot be handed work
  # in a project they cannot see.
  test "create rejects an assignee who is not a member of the project" do
    sign_in_as users(:one)

    assert_no_difference -> { Story.count } do
      post project_epic_stories_url(projects(:apollo), epics(:launch)),
           params: { story: { title: "Assigned to a stranger", assignee_id: users(:admin).id } }
    end

    assert_response :unprocessable_content
  end

  # "Member" is the floor the matrix draws for changing work, so it is tested
  # with a user who holds exactly that role rather than an owner standing in.
  test "create is allowed for a user whose role is member" do
    sign_in_as apollo_user(:member)

    assert_difference -> { epics(:launch).stories.count }, 1 do
      post project_epic_stories_url(projects(:apollo), epics(:launch)), params: { story: { title: "Hold logic" } }
    end
  end

  # The button and the permission behind it are now one question asked of one
  # policy, so a viewer is never offered a control that would only 403.
  test "index hides the new story button from a viewer and shows it to a member" do
    sign_in_as apollo_user(:viewer)
    get project_epic_stories_url(projects(:apollo), epics(:launch))
    assert_select "a[href=?]", new_project_epic_story_path(projects(:apollo), epics(:launch)), count: 0

    sign_in_as apollo_user(:member)
    get project_epic_stories_url(projects(:apollo), epics(:launch))
    assert_select "a[href=?]", new_project_epic_story_path(projects(:apollo), epics(:launch))
  end

  test "show hides the edit and delete controls from a viewer" do
    sign_in_as apollo_user(:viewer)

    get project_story_url(projects(:apollo), stories(:countdown))

    assert_select "a[href=?]", edit_project_story_path(projects(:apollo), stories(:countdown)), count: 0
    assert_select "form[action=?]", project_story_path(projects(:apollo), stories(:countdown)), count: 0
  end

  test "new is forbidden for a viewer" do
    sign_in_as users(:two)

    get new_project_epic_story_url(projects(:apollo), epics(:launch))

    assert_response :forbidden
  end

  # A form with no way out is a dead end. Cancel returns to the list the form
  # was opened from.
  test "new offers a cancel link back to the story list" do
    sign_in_as users(:one)

    get new_project_epic_story_url(projects(:apollo), epics(:launch))

    assert_select "a[href=?]", project_epic_stories_path(projects(:apollo), epics(:launch)), text: "Cancel"
  end

  # Cancelling an edit returns to the record being edited, not to the list —
  # that is the screen the Edit button was pressed on.
  test "edit offers a cancel link back to the story" do
    sign_in_as users(:one)

    get edit_project_story_url(projects(:apollo), stories(:abort_switch))

    assert_select "a[href=?]", project_story_path(projects(:apollo), stories(:abort_switch)), text: "Cancel"
  end

  # A viewer has no create button, but the form is trivially reconstructed by
  # hand — so the check cannot live in the view.
  test "create is forbidden for a viewer" do
    sign_in_as users(:two)

    assert_no_difference -> { Story.count } do
      post project_epic_stories_url(projects(:apollo), epics(:launch)), params: { story: { title: "Snuck in" } }
    end

    assert_response :forbidden
  end

  test "create re-renders with errors when the story is invalid" do
    sign_in_as users(:one)

    assert_no_difference -> { Story.count } do
      post project_epic_stories_url(projects(:apollo), epics(:launch)), params: { story: { title: "" } }
    end

    assert_response :unprocessable_content
  end

  # Mass assignment guard. epic_id comes from the path only: a story must not be
  # filed under an epic other than the one whose page it was created from.
  test "create ignores an epic_id smuggled in through the form" do
    sign_in_as users(:one)

    post project_epic_stories_url(projects(:apollo), epics(:launch)),
         params: { story: { title: "Relocated", epic_id: epics(:telemetry).id } }

    assert_equal epics(:launch), Story.find_by!(title: "Relocated").epic
  end

  # Status is set manually at every level (§3 rules out rollup), so changing it
  # is an ordinary update rather than a side effect of anything else.
  test "update changes the status for a member" do
    sign_in_as users(:one)

    patch project_story_url(projects(:apollo), stories(:countdown)), params: { story: { status: "in_progress" } }

    assert_redirected_to project_story_url(projects(:apollo), stories(:countdown))
    assert stories(:countdown).reload.in_progress?
  end

  # The direct-PATCH case from §4: a viewer bypassing the UI entirely.
  test "update is forbidden for a viewer" do
    sign_in_as users(:two)

    patch project_story_url(projects(:apollo), stories(:countdown)), params: { story: { title: "Vandalised" } }

    assert_response :forbidden
    assert_not_equal "Vandalised", stories(:countdown).reload.title
  end

  test "destroy removes the story for a member and returns to the epic" do
    sign_in_as users(:one)

    assert_difference -> { Story.count }, -1 do
      delete project_story_url(projects(:apollo), stories(:countdown))
    end

    assert_redirected_to project_epic_stories_url(projects(:apollo), epics(:launch))
  end

  test "destroy is forbidden for a viewer" do
    sign_in_as users(:two)

    assert_no_difference -> { Story.count } do
      delete project_story_url(projects(:apollo), stories(:countdown))
    end

    assert_response :forbidden
  end

  # A role in one project grants nothing in another, and a non-member gets the
  # same 404 whether the story exists or not.
  test "destroy returns 404 for a non-member rather than revealing the story" do
    sign_in_as users(:admin)

    assert_no_difference -> { Story.count } do
      delete project_story_url(projects(:apollo), stories(:countdown))
    end

    assert_response :not_found
  end
  # The same bar one level down, over tasks. A story can read 100% and still not
  # be done — §3 rules out rollup — so the bar and the status are separate
  # readings of the same row.
  test "show reports how many of the story's tasks are done" do
    sign_in_as users(:one)
    tasks(:wire_the_clock).done!

    get project_story_url(projects(:apollo), stories(:countdown))

    assert_select "[role=progressbar][aria-valuenow=?]", "50"
    assert_select "p", text: "1 of 2 tasks done"
    assert_select "dd", text: "Backlog"
  end
end
