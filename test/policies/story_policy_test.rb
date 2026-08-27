require "test_helper"

class StoryPolicyTest < ActiveSupport::TestCase
  def policy_for(user, story = stories(:countdown))
    StoryPolicy.new(user, story)
  end

  test "every role may view a story" do
    each_apollo_role do |role, user|
      assert policy_for(user).show?, "#{role} should be able to view the story"
    end
  end

  test "owner, admin and member may change a story" do
    %i[ owner admin member ].each do |role|
      policy = policy_for(apollo_user(role))

      assert policy.create?, "#{role} should be able to create"
      assert policy.update?, "#{role} should be able to update"
      assert policy.destroy?, "#{role} should be able to destroy"
    end
  end

  test "a viewer may not change a story" do
    policy = policy_for(apollo_user(:viewer))

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "a non-member may neither view nor change a story" do
    policy = policy_for(non_member)

    assert_not policy.show?
    assert_not policy.destroy?
  end

  # A story has no project_id of its own — it reaches one through its epic, so
  # the scope has to make the same hop the model's delegation makes.
  test "the scope returns only stories from projects the user belongs to" do
    resolved = StoryPolicy::Scope.new(apollo_user(:member), Story.all).resolve

    assert_includes resolved, stories(:countdown)
    assert_not_includes resolved, stories(:gemini_docking)
  end

  test "the scope is empty for a user with no memberships" do
    assert_empty StoryPolicy::Scope.new(non_member, Story.all).resolve
  end
end
