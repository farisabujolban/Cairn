require "test_helper"

class MilestonePolicyTest < ActiveSupport::TestCase
  def policy_for(user, milestone = milestones(:v1))
    MilestonePolicy.new(user, milestone)
  end

  # Matrix row 1: the schedule is readable by everyone on the project. Knowing
  # what ships when is the reason a viewer role exists.
  test "every role may view a milestone" do
    each_apollo_role do |role, user|
      assert policy_for(user).show?, "#{role} should be able to view the milestone"
    end
  end

  # Matrix row 3 — create / edit / delete milestones stops at member. Dates are
  # project work, not administration, so a member may move one.
  test "owner, admin and member may change a milestone" do
    %i[ owner admin member ].each do |role|
      policy = policy_for(apollo_user(role))

      assert policy.create?, "#{role} should be able to create"
      assert policy.update?, "#{role} should be able to update"
      assert policy.destroy?, "#{role} should be able to destroy"
    end
  end

  test "a viewer may not change a milestone" do
    policy = policy_for(apollo_user(:viewer))

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "a non-member may neither view nor change a milestone" do
    policy = policy_for(non_member)

    assert_not policy.show?
    assert_not policy.update?
  end

  # A milestone reaches its project directly, so the scope is one hop. This is
  # the query-level half of "it never appears in any index". The Apollo-only
  # member is the subject: Owner and Viewer are both in Gemini too, so neither
  # could show that the other project's rows are being excluded.
  test "the scope returns only milestones from projects the user belongs to" do
    resolved = MilestonePolicy::Scope.new(apollo_user(:member), Milestone.all).resolve

    assert_includes resolved, milestones(:v1)
    assert_not_includes resolved, milestones(:gemini_v1)
  end

  test "the scope is empty for a user with no memberships" do
    assert_empty MilestonePolicy::Scope.new(non_member, Milestone.all).resolve
  end
end
