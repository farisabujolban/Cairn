require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  # A membership is the only thing that grants access to a project, so it is
  # meaningless without both sides of the pair. A nil project_id would create a
  # grant that authorization code could not scope.
  test "is invalid without a user and a project" do
    membership = Membership.new(role: :member)
    assert_not membership.valid?
    assert_includes membership.errors[:user], "must exist"
    assert_includes membership.errors[:project], "must exist"
  end

  # Role is the entire permission matrix in one column. Defaulting it silently
  # would hand out whichever role happened to be first in the enum.
  test "is invalid without a role" do
    membership = Membership.new(user: users(:admin), project: projects(:gemini))
    assert_not membership.valid?
    assert_includes membership.errors[:role], "can't be blank"
  end

  # Anything outside the four roles has no row in the permission matrix, so
  # policies would have no defined answer for it. It is rejected as invalid
  # rather than raised on assignment, so a tampered form field is a 422 and not
  # a 500.
  test "rejects a role outside the permission matrix" do
    membership = Membership.new(user: users(:admin), project: projects(:archived), role: :superuser)
    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  # Two memberships for one user in one project would make "what is my role
  # here?" ambiguous, and a policy would answer with whichever row loaded first.
  test "is invalid when the user already has a membership in that project" do
    duplicate = Membership.new(user: users(:one), project: projects(:apollo), role: :viewer)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  # Exactly one owner per project. A second owner makes "transfer ownership" and
  # "delete project" ambiguous about who is entitled to do it.
  test "is invalid as a second owner of a project that already has one" do
    second_owner = Membership.new(user: users(:admin), project: projects(:apollo), role: :owner)
    assert_not second_owner.valid?
    assert_includes second_owner.errors[:role], "is already held by another member of this project"
  end

  # The one-owner rule is per project, not global. A user owning one project
  # must not stop anyone owning another, or only one project could ever exist.
  test "allows the owner of one project to own a different project" do
    membership = Membership.new(user: users(:one), project: projects(:archived), role: :owner)
    assert membership.valid?
  end

  # Demoting the last owner orphans the project: nobody would be left who can
  # transfer ownership or delete it, and no UI could recover from that.
  test "refuses to demote the last owner" do
    owner = memberships(:apollo_owner)
    assert_not owner.update(role: :admin)
    assert_includes owner.errors[:role], "cannot be changed while this is the project's only owner"
  end

  # Removing the last owner orphans the project the same way demoting does, and
  # a destroy bypasses update validations entirely, so it needs its own guard.
  test "refuses to destroy the last owner" do
    owner = memberships(:apollo_owner)
    assert_no_difference -> { Membership.count } do
      assert_not owner.destroy
    end
    assert_includes owner.errors[:base], "The project's only owner cannot be removed"
  end

  # Non-owners must stay freely removable — the last-owner guard is a rule about
  # ownership, and must not accidentally freeze every membership in the project.
  test "allows destroying a non-owner membership" do
    assert_difference -> { Membership.count }, -1 do
      assert memberships(:apollo_viewer).destroy
    end
  end
  # The member list reads as a hierarchy, so it has to sort as one. Ordering by
  # the role column directly sorts alphabetically — admin, member, owner, viewer
  # — which puts the owner third and reads as noise.
  test "by_role sorts most privileged first, then by name" do
    roles = projects(:apollo).memberships.by_role.map(&:role)

    assert_equal %w[ owner admin member viewer ], roles
  end

  # Two people in the same role is the common case, and an arbitrary order
  # within a role makes the list shuffle between page loads.
  test "by_role breaks ties on the member's name" do
    projects(:apollo).memberships.create!(user: users(:admin), role: :member)

    names = projects(:apollo).memberships.by_role.select(&:member?).map { |m| m.user.name }

    assert_equal names.sort, names
  end
end
