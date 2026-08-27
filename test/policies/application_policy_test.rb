require "test_helper"

class ApplicationPolicyTest < ActiveSupport::TestCase
  # Every work-item policy inherits these defaults, so they are the §4 matrix's
  # middle rows stated once. An Epic stands in for the record because the base
  # class is abstract and the defaults are exactly the work-item defaults.
  def policy_for(user, record = epics(:launch))
    ApplicationPolicy.new(user, record)
  end

  # Matrix row 1: viewing is the whole of membership. Every role sees every work
  # item in a project they belong to, which is what makes viewer a useful role
  # rather than a locked door.
  test "every role may show a record in a project they belong to" do
    each_apollo_role do |role, user|
      assert policy_for(user).show?, "#{role} should be able to view"
    end
  end

  # The single fact all four roles resolve through. A user with no membership
  # has no role, so every predicate below falls to false at once rather than
  # each one needing its own non-member check.
  test "a non-member has no role and may not view" do
    assert_not policy_for(non_member).show?
  end

  # Matrix rows 2 and 3: creating, editing and deleting work items is ordinary
  # project work, so it stops at member. Viewer is the line.
  test "owner, admin and member may create, update and destroy" do
    %i[ owner admin member ].each do |role|
      policy = policy_for(apollo_user(role))

      assert policy.create?, "#{role} should be able to create"
      assert policy.update?, "#{role} should be able to update"
      assert policy.destroy?, "#{role} should be able to destroy"
    end
  end

  # The one row that separates viewer from member. A viewer reads everything and
  # changes nothing, including through a request that never touched the UI.
  test "a viewer may not create, update or destroy" do
    policy = policy_for(apollo_user(:viewer))

    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  # new? and edit? are the form screens for create? and update?. Pinning them to
  # the same answer stops a form rendering for someone whose submit would 403.
  test "new and edit answer the same as create and update" do
    policy = policy_for(apollo_user(:viewer))

    assert_equal policy.create?, policy.new?
    assert_equal policy.update?, policy.edit?
  end

  # §4's last edge case: a role in project A grants nothing in project B. Two is
  # Gemini's owner and Apollo's viewer, so the same user answers differently
  # depending only on which project the record is in.
  test "a role in one project grants nothing in another" do
    owner_elsewhere = apollo_user(:viewer)

    assert policy_for(owner_elsewhere, epics(:gemini_rendezvous)).update?
    assert_not policy_for(owner_elsewhere, epics(:launch)).update?
  end

  # Records reach their project by containment rather than by storing it again,
  # so the role has to resolve the same way three levels down as at the top.
  test "the role resolves through containment for a story and a task" do
    member = apollo_user(:member)

    assert policy_for(member, stories(:countdown)).update?
    assert policy_for(member, tasks(:wire_the_clock)).update?
    assert_not policy_for(non_member, tasks(:wire_the_clock)).update?
  end

  # An unsaved record has no project rows to match, and treating "no membership
  # found" as a grant would open every create form to everyone.
  test "an unpersisted project yields no role" do
    assert_not policy_for(apollo_user(:owner), Project.new).show?
  end

  # A Scope subclass that forgets #resolve must fail loudly rather than return
  # nil and have the index silently render nothing.
  test "the base scope refuses to resolve" do
    assert_raises NoMethodError do
      ApplicationPolicy::Scope.new(apollo_user(:owner), Epic.all).resolve
    end
  end
end
