require "test_helper"

class TaskPolicyTest < ActiveSupport::TestCase
  def policy_for(user, task = tasks(:wire_the_clock))
    TaskPolicy.new(user, task)
  end

  test "every role may view a task" do
    each_apollo_role do |role, user|
      assert policy_for(user).show?, "#{role} should be able to view the task"
    end
  end

  # Ticking items off a checklist is the most ordinary work there is, so it sits
  # at the same member floor as everything else in rows 2 and 3.
  test "owner, admin and member may change a task" do
    %i[ owner admin member ].each do |role|
      policy = policy_for(apollo_user(role))

      assert policy.create?, "#{role} should be able to create"
      assert policy.update?, "#{role} should be able to update"
      assert policy.destroy?, "#{role} should be able to destroy"
    end
  end

  test "a viewer may not change a task" do
    policy = policy_for(apollo_user(:viewer))

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "a non-member may neither view nor change a task" do
    policy = policy_for(non_member)

    assert_not policy.show?
    assert_not policy.destroy?
  end

  # Three hops — task to story to epic to project. This is the deepest the tree
  # goes, and §6 guarantees it stays that way, so the scope cannot grow another.
  test "the scope returns only tasks from projects the user belongs to" do
    resolved = TaskPolicy::Scope.new(apollo_user(:member), Task.all).resolve

    assert_includes resolved, tasks(:wire_the_clock)
    assert_not_includes resolved, tasks(:gemini_latch)
  end

  test "the scope is empty for a user with no memberships" do
    assert_empty TaskPolicy::Scope.new(non_member, Task.all).resolve
  end
end
