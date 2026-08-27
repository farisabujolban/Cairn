require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  test "redirects a signed-out visitor to sign in" do
    get project_memberships_url(projects(:apollo))
    assert_redirected_to new_session_path
  end

  # The roster is readable by everyone on the project: assignee names already
  # appear throughout, and knowing who to ask about a task is ordinary use.
  test "index lists the project's members and their roles for a viewer" do
    sign_in_as apollo_user(:viewer)

    get project_memberships_url(projects(:apollo))

    assert_response :success
    assert_match apollo_user(:owner).name, response.body
    assert_match apollo_user(:member).name, response.body
  end

  # A project's roster is as private as the project. Listing another project's
  # members here would leak both the people and the fact of the project.
  test "index excludes members of another project" do
    sign_in_as apollo_user(:member)

    get project_memberships_url(projects(:apollo))

    assert_no_match(/#{users(:admin).name}/, response.body)
  end

  test "index returns 404 for a non-member" do
    sign_in_as non_member

    get project_memberships_url(projects(:apollo))

    assert_response :not_found
  end

  # Matrix row 4. The add control is the visible half of the same permission the
  # controller enforces, so it must not be offered to a member or a viewer.
  test "index offers the add control to an admin but not to a member" do
    sign_in_as apollo_user(:admin)
    get project_memberships_url(projects(:apollo))
    assert_select "a[href=?]", new_project_membership_path(projects(:apollo))

    sign_in_as apollo_user(:member)
    get project_memberships_url(projects(:apollo))
    assert_select "a[href=?]", new_project_membership_path(projects(:apollo)), count: 0
  end

  test "an admin may add a member" do
    sign_in_as apollo_user(:admin)

    assert_difference -> { projects(:apollo).memberships.count }, 1 do
      post project_memberships_url(projects(:apollo)),
           params: { membership: { user_id: non_member.id, role: "member" } }
    end

    assert_equal "member", projects(:apollo).memberships.find_by(user: non_member).role
  end

  # The form is trivially reconstructed, so the check cannot live in the view.
  test "a member may not add a member" do
    sign_in_as apollo_user(:member)

    assert_no_difference -> { Membership.count } do
      post project_memberships_url(projects(:apollo)),
           params: { membership: { user_id: non_member.id, role: "member" } }
    end

    assert_response :forbidden
  end

  # Ownership is set when the project is created and moved by transfer. Adding
  # somebody straight in as owner would sidestep both, and the one-owner rule
  # with them.
  test "adding a member as owner is refused" do
    sign_in_as apollo_user(:owner)

    assert_no_difference -> { Membership.count } do
      post project_memberships_url(projects(:apollo)),
           params: { membership: { user_id: non_member.id, role: "owner" } }
    end

    assert_response :forbidden
  end

  # project_id comes from the path. Accepting it from the form would let an
  # admin of one project grant themselves access to another.
  test "create ignores a project_id smuggled in through the form" do
    sign_in_as apollo_user(:admin)

    post project_memberships_url(projects(:apollo)),
         params: { membership: { user_id: non_member.id, role: "member", project_id: projects(:gemini).id } }

    assert_equal projects(:apollo), Membership.find_by!(user: non_member).project
  end

  test "an admin may change an ordinary member's role" do
    sign_in_as apollo_user(:admin)

    patch project_membership_url(projects(:apollo), memberships(:apollo_member)),
          params: { membership: { role: "viewer" } }

    assert_redirected_to project_memberships_url(projects(:apollo))
    assert_equal "viewer", memberships(:apollo_member).reload.role
  end

  test "an admin may remove an ordinary member" do
    sign_in_as apollo_user(:admin)

    assert_difference -> { Membership.count }, -1 do
      delete project_membership_url(projects(:apollo), memberships(:apollo_member))
    end

    assert_redirected_to project_memberships_url(projects(:apollo))
  end

  test "a viewer may not change anyone's role" do
    sign_in_as apollo_user(:viewer)

    patch project_membership_url(projects(:apollo), memberships(:apollo_member)),
          params: { membership: { role: "admin" } }

    assert_response :forbidden
    assert_equal "member", memberships(:apollo_member).reload.role
  end

  # §4's edge case: an admin runs the project day to day but cannot take it.
  # Demoting the owner would let them do exactly that.
  test "an admin may not demote the owner" do
    sign_in_as apollo_user(:admin)

    patch project_membership_url(projects(:apollo), memberships(:apollo_owner)),
          params: { membership: { role: "member" } }

    assert_response :forbidden
    assert_equal "owner", memberships(:apollo_owner).reload.role
  end

  test "an admin may not remove the owner" do
    sign_in_as apollo_user(:admin)

    assert_no_difference -> { Membership.count } do
      delete project_membership_url(projects(:apollo), memberships(:apollo_owner))
    end

    assert_response :forbidden
  end

  # §4's other edge case: the last owner cannot demote or remove themselves,
  # because the project would be left with nobody able to transfer or delete it.
  # There is only ever one owner, so this is always the last one.
  test "the owner may not demote themselves" do
    sign_in_as apollo_user(:owner)

    patch project_membership_url(projects(:apollo), memberships(:apollo_owner)),
          params: { membership: { role: "admin" } }

    assert_response :forbidden
    assert_equal "owner", memberships(:apollo_owner).reload.role
  end

  # Matrix row 6. Transfer is the sanctioned way out of the rule above: it
  # promotes the incoming owner and demotes the outgoing one in one transaction,
  # so the project is never left with two owners or none.
  test "the owner may transfer ownership to another member" do
    sign_in_as apollo_user(:owner)

    patch project_membership_url(projects(:apollo), memberships(:apollo_admin)),
          params: { membership: { role: "owner" } }

    assert_redirected_to project_memberships_url(projects(:apollo))
    assert_equal "owner", memberships(:apollo_admin).reload.role
    assert_equal "admin", memberships(:apollo_owner).reload.role
    assert_equal 1, projects(:apollo).memberships.owner.count
  end

  # An admin may edit roles, so without this the transfer path would be a way
  # around matrix row 6 — the one row that stops at the owner alone.
  test "an admin may not transfer ownership to themselves" do
    sign_in_as apollo_user(:admin)

    patch project_membership_url(projects(:apollo), memberships(:apollo_admin)),
          params: { membership: { role: "owner" } }

    assert_response :forbidden
    assert_equal "admin", memberships(:apollo_admin).reload.role
    assert_equal apollo_user(:owner), projects(:apollo).memberships.owner.sole.user
  end

  # A membership id from another project paired with this project's path must
  # resolve to nothing rather than being edited.
  test "update returns 404 for a membership belonging to another project" do
    sign_in_as apollo_user(:owner)

    patch project_membership_url(projects(:apollo), memberships(:gemini_owner)),
          params: { membership: { role: "viewer" } }

    assert_response :not_found
  end

  # The add form must not offer people who are already on the project — picking
  # one would only fail the uniqueness rule on the pair.
  test "new offers only users who are not already members" do
    sign_in_as apollo_user(:owner)

    get new_project_membership_url(projects(:apollo))

    assert_response :success
    assert_select "option", text: non_member.name
    assert_select "option", text: apollo_user(:member).name, count: 0
  end

  # Owner is not a role you assign; it is a transfer. It stays off the add form
  # entirely, and off the role menu for anyone who is not the owner.
  test "the role menu offers owner to the owner and withholds it from an admin" do
    sign_in_as apollo_user(:owner)
    get project_memberships_url(projects(:apollo))
    assert_select "select[name=?] option[value=owner]", "membership[role]"

    sign_in_as apollo_user(:admin)
    get project_memberships_url(projects(:apollo))
    assert_select "select[name=?] option[value=owner]", "membership[role]", count: 0
  end

  # The project page is the only way in, so the link has to be there for every
  # role that can reach the list — which is all of them.
  test "the project page links to the member list" do
    sign_in_as apollo_user(:viewer)

    get project_url(projects(:apollo))

    assert_select "a[href=?]", project_memberships_path(projects(:apollo))
  end
end
