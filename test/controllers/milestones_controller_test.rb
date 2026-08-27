require "test_helper"

class MilestonesControllerTest < ActionDispatch::IntegrationTest
  # Every milestone screen sits behind sign-in, like every other project screen.
  test "redirects a signed-out visitor to sign in" do
    get project_milestones_url(projects(:apollo))
    assert_redirected_to new_session_path
  end

  # Milestones are per project. A milestone belonging to another project must
  # not appear here even for a user who is a member of both.
  test "index lists only the milestones of the project in the path" do
    sign_in_as users(:one)

    get project_milestones_url(projects(:apollo))

    assert_response :success
    assert_match milestones(:v1).title, response.body
    assert_no_match(/#{milestones(:gemini_v1).title}/, response.body)
  end

  # 404 rather than 403: the milestone list of a project a user is not in must
  # not confirm that the project exists.
  test "index returns 404 for a non-member" do
    sign_in_as users(:admin)

    get project_milestones_url(projects(:apollo))

    assert_response :not_found
  end

  # Viewers read everything — that is the whole of their role, and withholding
  # the read would make the role useless.
  test "show renders for a viewer" do
    sign_in_as users(:two)

    get project_milestone_url(projects(:apollo), milestones(:v1))

    assert_response :success
    assert_match milestones(:v1).title, response.body
  end

  # The lookup runs through the project's own milestones, so pairing one
  # project's path with another project's milestone id resolves to nothing.
  test "show returns 404 for a milestone belonging to a different project" do
    sign_in_as users(:one)

    get project_milestone_url(projects(:apollo), milestones(:gemini_v1))

    assert_response :not_found
  end

  # Per the §4 matrix, creating milestones is a member-level privilege: it is
  # ordinary project work, not administration.
  test "create is allowed for a member" do
    sign_in_as users(:one)

    assert_difference -> { projects(:gemini).milestones.count }, 1 do
      post project_milestones_url(projects(:gemini)),
           params: { milestone: { title: "Gemini v2", due_on: 10.days.from_now.to_date } }
    end

    assert_redirected_to project_milestones_url(projects(:gemini))
  end

  # A viewer has no create button, but the form is trivially reconstructed by
  # hand — so the check cannot live in the view.
  test "create is forbidden for a viewer" do
    sign_in_as users(:two)

    assert_no_difference -> { Milestone.count } do
      post project_milestones_url(projects(:apollo)), params: { milestone: { title: "Snuck in" } }
    end

    assert_response :forbidden
  end

  # A form with no way out is a dead end: the only exit was the browser's back
  # button. Cancel returns to the list the form was opened from.
  test "new offers a cancel link back to the milestone list" do
    sign_in_as users(:one)

    get new_project_milestone_url(projects(:apollo))

    assert_select "a[href=?]", project_milestones_path(projects(:apollo)), text: "Cancel"
  end

  # Cancelling an edit returns to the record being edited, not to the list —
  # that is the screen the Edit button was pressed on.
  test "edit offers a cancel link back to the milestone" do
    sign_in_as users(:one)

    get edit_project_milestone_url(projects(:apollo), milestones(:v1))

    assert_select "a[href=?]", project_milestone_path(projects(:apollo), milestones(:v1)), text: "Cancel"
  end

  test "new is forbidden for a viewer" do
    sign_in_as users(:two)

    get new_project_milestone_url(projects(:apollo))

    assert_response :forbidden
  end

  # An invalid submission re-renders with errors rather than 500-ing or
  # silently discarding what the user typed.
  test "create re-renders with errors when the milestone is invalid" do
    sign_in_as users(:one)

    assert_no_difference -> { Milestone.count } do
      post project_milestones_url(projects(:apollo)), params: { milestone: { title: "" } }
    end

    assert_response :unprocessable_content
  end

  # Mass assignment guard. project_id must never be settable from the form: a
  # member of Apollo could otherwise plant a milestone inside Gemini.
  test "create ignores a project_id smuggled in through the form" do
    sign_in_as users(:one)

    post project_milestones_url(projects(:apollo)),
         params: { milestone: { title: "Relocated", project_id: projects(:gemini).id } }

    assert_equal projects(:apollo), Milestone.find_by!(title: "Relocated").project
  end

  test "update saves changes for a member" do
    sign_in_as users(:one)

    patch project_milestone_url(projects(:apollo), milestones(:v1)),
          params: { milestone: { title: "v1.1 (slipped)", state: "closed" } }

    assert_redirected_to project_milestone_url(projects(:apollo), milestones(:v1))
    assert_equal "v1.1 (slipped)", milestones(:v1).reload.title
    assert milestones(:v1).closed?
  end

  # The direct-PATCH case from §4: a viewer bypassing the UI entirely.
  test "update is forbidden for a viewer" do
    sign_in_as users(:two)

    patch project_milestone_url(projects(:apollo), milestones(:v1)),
          params: { milestone: { title: "Vandalised" } }

    assert_response :forbidden
    assert_not_equal "Vandalised", milestones(:v1).reload.title
  end

  test "destroy removes the milestone for a member" do
    sign_in_as users(:one)

    assert_difference -> { Milestone.count }, -1 do
      delete project_milestone_url(projects(:apollo), milestones(:v1))
    end

    assert_redirected_to project_milestones_url(projects(:apollo))
  end

  # Destruction is the most damaging thing a viewer could reach, and it is the
  # one most likely to be attempted directly rather than through a button.
  test "destroy is forbidden for a viewer" do
    sign_in_as users(:two)

    assert_no_difference -> { Milestone.count } do
      delete project_milestone_url(projects(:apollo), milestones(:v1))
    end

    assert_response :forbidden
  end

  # A role in one project grants nothing in another: Two owns Gemini, which
  # must not let them touch Apollo's schedule.
  test "destroy returns 404 for a non-member rather than revealing the milestone" do
    sign_in_as users(:admin)

    assert_no_difference -> { Milestone.count } do
      delete project_milestone_url(projects(:apollo), milestones(:v1))
    end

    assert_response :not_found
  end
end
