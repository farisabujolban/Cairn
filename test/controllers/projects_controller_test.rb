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

  # A slug that matches nothing and a slug the user may not see must be
  # indistinguishable, or the difference becomes an existence oracle.
  test "show returns 404 for a slug that does not exist" do
    sign_in_as users(:one)

    get project_url(id: "no-such-project")

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
end
