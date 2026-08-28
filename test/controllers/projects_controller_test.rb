require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  # Every project screen is behind sign-in. An anonymous request must not reach
  # the listing at all, rather than reaching an empty one.
  test "redirects a signed-out visitor to sign in" do
    get projects_url
    assert_redirected_to new_session_path
  end

  # The index is scoped by membership, not by existence. Gemini's name must not
  # appear in the markup at all — leaking the title is leaking the project.
  test "index lists only the projects the signed-in user is a member of" do
    sign_in_as users(:one)
    memberships(:gemini_member).destroy

    get projects_url

    assert_response :success
    assert_match projects(:apollo).name, response.body
    assert_no_match(/#{projects(:gemini).name}/, response.body)
  end

  # A system_admin with no memberships sees an empty list. The bootstrap
  # privilege creates users and projects; it is not read access to every team.
  test "index shows a system admin no projects they are not a member of" do
    sign_in_as users(:admin)

    get projects_url

    assert_response :success
    assert_no_match(/#{projects(:apollo).name}/, response.body)
  end

  test "show renders a project the user is a member of" do
    sign_in_as users(:one)

    get project_url(projects(:apollo))

    assert_response :success
    assert_match projects(:apollo).name, response.body
  end

  # 404 and not 403: a 403 confirms the project exists, which is exactly the
  # fact a non-member must not learn.
  test "show returns 404 for a project the user is not a member of" do
    sign_in_as users(:admin)

    get project_url(projects(:apollo))

    assert_response :not_found
  end

  # An id that matches nothing and an id the user may not see must be
  # indistinguishable, or the difference becomes an existence oracle.
  test "show returns 404 for an id that does not exist" do
    sign_in_as users(:one)

    get project_url(id: 0)

    assert_response :not_found
  end

  # Sign-up is disabled, so project creation is the system admin's bootstrap
  # privilege. An ordinary member must not be able to create one.
  test "new is forbidden for a user who is not a system admin" do
    sign_in_as users(:one)

    get new_project_url

    assert_response :forbidden
  end

  test "new renders for a system admin" do
    sign_in_as users(:admin)

    get new_project_url

    assert_response :success
  end

  # A form with no way out is a dead end: the only exit was the browser's back
  # button. Cancel returns to the list the form was opened from.
  test "new offers a cancel link back to the project list" do
    sign_in_as users(:admin)

    get new_project_url

    assert_select "a[href=?]", projects_path, text: "Cancel"
  end

  # Cancelling an edit returns to the record being edited, not to the list —
  # that is the screen the Edit button was pressed on.
  test "edit offers a cancel link back to the project" do
    sign_in_as users(:one)

    get edit_project_url(projects(:apollo))

    assert_select "a[href=?]", project_path(projects(:apollo)), text: "Cancel"
  end

  # A project with no owner cannot be transferred or deleted by anyone, so the
  # owning membership is created in the same breath as the project.
  test "create makes the creating system admin the owner" do
    sign_in_as users(:admin)

    assert_difference -> { Project.count }, 1 do
      post projects_url, params: { project: { name: "New Initiative", description: "Ships in Q3" } }
    end

    project = Project.find_by!(slug: "new-initiative")
    assert_redirected_to project_url(project)
    assert_equal "owner", project.memberships.sole.role
    assert_equal users(:admin), project.memberships.sole.user
  end

  # An invalid submission must re-render with errors rather than 500 or silently
  # drop the input, and it must not leave a half-created project behind.
  test "create re-renders with errors when the project is invalid" do
    sign_in_as users(:admin)

    assert_no_difference -> { Project.count } do
      post projects_url, params: { project: { name: "" } }
    end

    assert_response :unprocessable_content
  end

  # Mass assignment guard: system_admin is the one privilege that must never be
  # settable through a project form, and archived_at would soft-delete on create.
  test "create ignores parameters outside the permitted list" do
    sign_in_as users(:admin)

    post projects_url, params: { project: { name: "Sneaky", archived_at: 1.day.ago } }

    assert_nil Project.find_by!(slug: "sneaky").archived_at
  end

  test "update saves changes for an owner" do
    sign_in_as users(:one)

    patch project_url(projects(:apollo)), params: { project: { description: "Rewritten" } }

    assert_redirected_to project_url(projects(:apollo))
    assert_equal "Rewritten", projects(:apollo).reload.description
  end

  # The matrix puts editing the project at administrator level, so an admin is
  # the highest role that is not the owner and must still be allowed through.
  test "update saves changes for a project admin" do
    sign_in_as apollo_user(:admin)

    patch project_url(projects(:apollo)), params: { project: { description: "Edited by an admin" } }

    assert_redirected_to project_url(projects(:apollo))
    assert_equal "Edited by an admin", projects(:apollo).reload.description
  end

  # The line the matrix draws between project work and project administration:
  # a member files epics all day and still cannot rename the project.
  test "update is forbidden for a member" do
    sign_in_as apollo_user(:member)

    patch project_url(projects(:apollo)), params: { project: { description: "Renamed" } }

    assert_response :forbidden
    assert_not_equal "Renamed", projects(:apollo).reload.description
  end

  # 403 rather than 404 here: a viewer already knows the project exists, so
  # hiding it would only be confusing. The role, not the project, is the problem.
  test "update is forbidden for a viewer" do
    sign_in_as users(:two)

    patch project_url(projects(:apollo)), params: { project: { description: "Vandalised" } }

    assert_response :forbidden
    assert_not_equal "Vandalised", projects(:apollo).reload.description
  end

  # The direct-PATCH case: a viewer who never sees an edit button can still
  # craft the request by hand, so the check cannot live in the view.
  test "update returns 404 for a non-member rather than revealing the project" do
    sign_in_as users(:admin)

    patch project_url(projects(:apollo)), params: { project: { description: "Outsider" } }

    assert_response :not_found
  end

  # The default listing is the live work. An archived project still exists and
  # is still readable, but it has been put away, and the list people open all
  # day should not be where it stays.
  test "index shows only active projects by default" do
    sign_in_as users(:one)
    projects(:apollo).archive!

    get projects_url

    assert_no_match(/#{projects(:apollo).name}/, response.body)
    assert_match projects(:gemini).name, response.body
  end

  # The other half of the toggle. Without a screen that lists archived projects,
  # archiving is a one-way trip: the project is hidden from the only list that
  # could bring it back.
  test "index lists the archived projects when asked for them" do
    sign_in_as users(:one)
    projects(:apollo).archive!

    get projects_url(status: "archived")

    assert_response :success
    assert_match projects(:apollo).name, response.body
    assert_no_match(/#{projects(:gemini).name}/, response.body)
  end

  # The archived listing is a filter on the same scope, not a way around it.
  # Mercury is archived and belongs to nobody, so membership must still decide.
  test "index does not leak archived projects the user is not a member of" do
    sign_in_as users(:one)

    get projects_url(status: "archived")

    assert_response :success
    assert_no_match(/#{projects(:archived).name}/, response.body)
  end

  # An unrecognised filter value must fall back to the live list rather than
  # being passed to the model — the parameter names a scope, and only these two
  # scopes may be named.
  test "index falls back to the active listing for an unknown status" do
    sign_in_as users(:one)
    projects(:apollo).archive!

    get projects_url(status: "destroy_all")

    assert_response :success
    assert_no_match(/#{projects(:apollo).name}/, response.body)
  end

  # Matrix row 5. Archiving lands on the archived listing rather than the active
  # one, so the person who just archived sees where the project went and that
  # Restore is sitting next to it.
  test "archive puts the project away for an admin" do
    sign_in_as apollo_user(:admin)

    patch archive_project_url(projects(:apollo))

    assert_redirected_to projects_path(status: "archived")
    assert projects(:apollo).reload.archived?
  end

  # A member files epics all day and still cannot put the whole project away —
  # the same line the matrix draws for renaming it.
  test "archive is forbidden for a member" do
    sign_in_as apollo_user(:member)

    patch archive_project_url(projects(:apollo))

    assert_response :forbidden
    assert_not projects(:apollo).reload.archived?
  end

  test "archive returns 404 for a non-member rather than revealing the project" do
    sign_in_as users(:admin)

    patch archive_project_url(projects(:apollo))

    assert_response :not_found
    assert_not projects(:apollo).reload.archived?
  end

  # The return trip, which is what makes archiving reversible rather than a soft
  # delete nobody can undo.
  test "restore brings the project back for an admin" do
    sign_in_as apollo_user(:admin)
    projects(:apollo).archive!

    patch restore_project_url(projects(:apollo))

    assert_redirected_to project_path(projects(:apollo))
    assert_not projects(:apollo).reload.archived?
  end

  test "restore is forbidden for a member" do
    sign_in_as apollo_user(:member)
    projects(:apollo).archive!

    patch restore_project_url(projects(:apollo))

    assert_response :forbidden
    assert projects(:apollo).reload.archived?
  end

  # Matrix row 6, and the route that has been a 404 since phase 1: DELETE was
  # routed with no action behind it.
  test "destroy deletes the project and its contents for the owner" do
    sign_in_as apollo_user(:owner)

    # Counted at two levels: the cascade is the whole reason this row stops at
    # the owner, so a delete that took the project and left its epics behind
    # would be a worse bug than one that refused.
    assert_difference -> { Project.count } => -1, -> { Epic.count } => -2,
                      -> { Story.count } => -3, -> { Task.count } => -2 do
      delete project_url(projects(:apollo))
    end

    assert_redirected_to projects_path
  end

  # The cascade is the reason this stops at the owner: an admin deleting a
  # project takes every epic, story and task in it, and nobody can undo that.
  test "destroy is forbidden for a project admin" do
    sign_in_as apollo_user(:admin)

    assert_no_difference -> { Project.count } do
      delete project_url(projects(:apollo))
    end

    assert_response :forbidden
  end

  test "destroy returns 404 for a non-member rather than revealing the project" do
    sign_in_as users(:admin)

    assert_no_difference -> { Project.count } do
      delete project_url(projects(:apollo))
    end

    assert_response :not_found
  end

  # The way back has to be on the screen, not just in the routes file. An
  # archived project the user can restore is useless if the listing shows it
  # without a control.
  test "the archived listing offers a restore button" do
    sign_in_as apollo_user(:admin)
    projects(:apollo).archive!

    get projects_url(status: "archived")

    assert_select "form[action=?][method=post]", restore_project_path(projects(:apollo))
  end

  # A control that appears when the request behind it would be refused teaches
  # people the app is broken. Both halves ask the same policy, so both change
  # together.
  test "a member is shown neither the archive nor the delete control" do
    sign_in_as apollo_user(:member)

    get project_url(projects(:apollo))

    assert_response :success
    assert_select "form[action=?]", archive_project_path(projects(:apollo)), count: 0
    # Scoped to this project's path: the layout's own Sign out button is a
    # DELETE too, and an unscoped selector would match it and pass regardless.
    assert_select "form[action=?] input[value=delete]", project_path(projects(:apollo)), count: 0
  end

  # Matrix row 6 in the markup: an admin runs the project day to day and still
  # cannot destroy it, so the button is absent rather than merely refused.
  test "an admin may archive the project but is not shown the delete control" do
    sign_in_as apollo_user(:admin)

    get project_url(projects(:apollo))

    assert_select "form[action=?]", archive_project_path(projects(:apollo))
    assert_select "form[action=?] input[value=delete]", project_path(projects(:apollo)), count: 0
  end

  # The confirmation is the last thing between a wrong click and a cascade that
  # reaches four levels down, so it has to name the cascade rather than ask "are
  # you sure?".
  test "the delete control confirms with what would be destroyed" do
    sign_in_as apollo_user(:owner)

    get project_url(projects(:apollo))

    # Addressed by the delete form's own action: the Archive button beside it
    # also carries a turbo-confirm, and it is the shorter, reversible one.
    delete_form = css_select("form[action='#{project_path(projects(:apollo))}'][data-turbo-confirm]").sole
    confirmation = delete_form["data-turbo-confirm"]
    assert_includes confirmation, "Apollo"
    assert_includes confirmation, "2 epics"
    assert_includes confirmation, "3 stories"
    assert_includes confirmation, "cannot be undone"
  end
  # §7's key screen. Every other list in the app shows one level at a time —
  # reaching a task means five navigations and you can never see two epics at
  # once — so the one screen that shows containment whole is the project page.
  test "show renders all three levels of the backlog tree" do
    sign_in_as users(:one)

    get project_url(projects(:apollo))

    assert_response :success
    assert_match epics(:launch).title, response.body
    assert_match stories(:countdown).title, response.body
    assert_match tasks(:wire_the_clock).title, response.body
  end

  # The tree has more rows than any other screen, so it is the one place an N+1
  # actually hurts. Asserted as "does not grow with the tree" rather than as a
  # fixed number, which would only be a change detector.
  test "the backlog tree does not query per row" do
    sign_in_as users(:one)
    get project_url(projects(:apollo))

    before = queries_for { get project_url(projects(:apollo)) }

    epic = projects(:apollo).epics.create!(title: "Added epic")
    3.times do |n|
      story = epic.stories.create!(title: "Added story #{n}")
      3.times { |m| story.tasks.create!(title: "Added task #{m}") }
    end

    assert_equal before, queries_for { get project_url(projects(:apollo)) },
      "the tree gained queries when it gained rows, so something in it queries per row"
  end

  # Membership decides what the tree contains, the same as every other listing.
  # A tree is a tempting place to reach past the scope because the rows are
  # nested, and nesting is not authorization.
  test "the backlog tree shows nothing from another project" do
    sign_in_as users(:one)

    get project_url(projects(:apollo))

    assert_no_match(/#{epics(:gemini_rendezvous).title}/, response.body)
    assert_no_match(/#{stories(:gemini_docking).title}/, response.body)
  end

  # A project with no epics is the first thing a new team sees, so it says what
  # to do rather than rendering an empty box.
  test "the backlog tree offers an empty state when the project has no epics" do
    sign_in_as users(:one)
    projects(:apollo).epics.destroy_all

    get project_url(projects(:apollo))

    assert_response :success
    assert_select "a[href=?]", new_project_epic_path(projects(:apollo))
  end

  private
    def queries_for
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      count
    end
end
