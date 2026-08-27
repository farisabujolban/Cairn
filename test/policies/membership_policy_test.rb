require "test_helper"

class MembershipPolicyTest < ActiveSupport::TestCase
  def policy_for(user, membership = memberships(:apollo_member))
    MembershipPolicy.new(user, membership)
  end

  # Not in the matrix as its own row, and decided here: seeing who else is on
  # the project is part of viewing the project. Assignee names already appear on
  # every story and task a viewer can open, so hiding the roster would conceal
  # nothing while making it impossible to know who to ask about a task.
  test "every role may see the member list" do
    each_apollo_role do |role, user|
      assert policy_for(user).index?, "#{role} should be able to see the members"
    end
  end

  test "a non-member may not see the member list" do
    assert_not policy_for(non_member).index?
  end

  # Matrix row 4 — add & remove members, assign roles: owner and admin. This is
  # the row that makes admin a distinct role rather than a synonym for member.
  test "owner and admin may add members, member and viewer may not" do
    assert policy_for(apollo_user(:owner)).create?
    assert policy_for(apollo_user(:admin)).create?
    assert_not policy_for(apollo_user(:member)).create?
    assert_not policy_for(apollo_user(:viewer)).create?
  end

  test "owner and admin may change and remove an ordinary member" do
    %i[ owner admin ].each do |role|
      policy = policy_for(apollo_user(role))

      assert policy.update?, "#{role} should be able to change a member's role"
      assert policy.destroy?, "#{role} should be able to remove a member"
    end
  end

  test "a member and a viewer may not change or remove anyone" do
    %i[ member viewer ].each do |role|
      policy = policy_for(apollo_user(role))

      assert_not policy.update?, "#{role} should not change roles"
      assert_not policy.destroy?, "#{role} should not remove members"
    end
  end

  # §4's edge case: an admin cannot demote or remove the owner. Without this an
  # admin could quietly take the project from under the person who owns it,
  # which makes "exactly one owner" a formality rather than a protection.
  test "an admin may not touch the owner's membership" do
    policy = policy_for(apollo_user(:admin), memberships(:apollo_owner))

    assert_not policy.update?
    assert_not policy.destroy?
  end

  # §4's other edge case: the last owner cannot be demoted or removed, because
  # it would orphan the project — nobody left who can transfer or delete it.
  # There is only ever one owner, so the owner's own membership is always the
  # last one. Transfer is the sanctioned way out, and it is a different action.
  test "the owner may not remove or demote their own membership" do
    policy = policy_for(apollo_user(:owner), memberships(:apollo_owner))

    assert_not policy.update?
    assert_not policy.destroy?
  end

  # A role in project A grants nothing in project B, stated on the row that
  # would hand out roles — the most damaging place for it to be wrong.
  test "an owner elsewhere may not manage members here" do
    gemini_owner = apollo_user(:viewer)

    assert MembershipPolicy.new(gemini_owner, memberships(:gemini_member)).update?
    assert_not policy_for(gemini_owner).update?
  end

  # Owner is not a role you pick from a menu — the project has exactly one, and
  # moving it is a transfer (matrix row 6). The menu the view renders therefore
  # has to be the policy's answer, not a bare list of the enum's values.
  test "the role menu withholds owner from an admin" do
    assert_equal %w[ admin member viewer ], policy_for(apollo_user(:admin)).assignable_roles
  end

  # For the owner it is offered, because for them choosing it is the transfer —
  # the one sanctioned way the owner slot moves.
  test "the role menu offers owner to the owner" do
    assert_equal Membership::ROLES, policy_for(apollo_user(:owner)).assignable_roles
  end

  # Handing the project to somebody who is not on it yet would transfer past the
  # step where they are given access at all, so the add form never offers owner.
  test "the role menu withholds owner when adding a new member" do
    fresh = projects(:apollo).memberships.new

    assert_equal %w[ admin member viewer ], MembershipPolicy.new(apollo_user(:owner), fresh).assignable_roles
  end

  # Ownership arrives with the project or by transfer. Creating a membership
  # that is already the owner sidesteps both, and the one-owner rule with them.
  test "nobody may add a member who is already the owner" do
    fresh = projects(:apollo).memberships.new(role: :owner)

    assert_not MembershipPolicy.new(apollo_user(:owner), fresh).create?
  end

  # The roster of a project you are not in must not be listable, and the scope
  # is what keeps that true in the query rather than in the view.
  test "the scope returns only memberships of projects the user belongs to" do
    resolved = MembershipPolicy::Scope.new(apollo_user(:member), Membership.all).resolve

    assert_includes resolved, memberships(:apollo_owner)
    assert_not_includes resolved, memberships(:gemini_owner)
  end

  test "the scope is empty for a user with no memberships" do
    assert_empty MembershipPolicy::Scope.new(non_member, Membership.all).resolve
  end
end
