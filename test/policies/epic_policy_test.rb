require "test_helper"

class EpicPolicyTest < ActiveSupport::TestCase
  def policy_for(user, epic = epics(:launch))
    EpicPolicy.new(user, epic)
  end

  test "every role may view an epic" do
    each_apollo_role do |role, user|
      assert policy_for(user).show?, "#{role} should be able to view the epic"
    end
  end

  # Matrix row 2 — filing and reshaping epics is ordinary project work, so the
  # floor is member rather than admin.
  test "owner, admin and member may change an epic" do
    %i[ owner admin member ].each do |role|
      policy = policy_for(apollo_user(role))

      assert policy.create?, "#{role} should be able to create"
      assert policy.update?, "#{role} should be able to update"
      assert policy.destroy?, "#{role} should be able to destroy"
    end
  end

  test "a viewer may not change an epic" do
    policy = policy_for(apollo_user(:viewer))

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "a non-member may neither view nor change an epic" do
    policy = policy_for(non_member)

    assert_not policy.show?
    assert_not policy.destroy?
  end

  # An epic reaches its project directly. The Apollo-only member is the subject
  # because Owner and Viewer are both in Gemini too.
  test "the scope returns only epics from projects the user belongs to" do
    resolved = EpicPolicy::Scope.new(apollo_user(:member), Epic.all).resolve

    assert_includes resolved, epics(:launch)
    assert_not_includes resolved, epics(:gemini_rendezvous)
  end

  test "the scope is empty for a user with no memberships" do
    assert_empty EpicPolicy::Scope.new(non_member, Epic.all).resolve
  end
end
