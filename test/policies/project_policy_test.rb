require "test_helper"

class ProjectPolicyTest < ActiveSupport::TestCase
  def policy_for(user, project = projects(:apollo))
    ProjectPolicy.new(user, project)
  end

  # Matrix row 1. A viewer is a full reader of the project itself, not just of
  # the work inside it.
  test "every role may view the project" do
    each_apollo_role do |role, user|
      assert policy_for(user).show?, "#{role} should be able to view the project"
    end
  end

  # §4's headline rule: a non-member must not learn the project exists. The
  # policy says no here and the controller turns that into 404 rather than 403.
  test "a non-member may not view the project" do
    assert_not policy_for(non_member).show?
  end

  # The listing itself is open to anyone signed in — there is no project in
  # hand to hold a role over. What it contains is the scope's job, below.
  test "the index is open and the scope decides its contents" do
    assert policy_for(non_member).index?
  end

  # Sign-up is disabled, so creating projects is the system admin's bootstrap
  # privilege. It is deliberately not a project role: there is no project yet.
  test "only a system admin may create a project" do
    assert policy_for(users(:admin), Project.new).create?

    each_apollo_role do |role, user|
      assert_not policy_for(user, Project.new).create?, "#{role} should not create projects"
    end
  end

  # Editing the project's own name and description is administration, not
  # project work — the same tier the matrix puts archiving at.
  test "owner and admin may update the project, member and viewer may not" do
    assert policy_for(apollo_user(:owner)).update?
    assert policy_for(apollo_user(:admin)).update?
    assert_not policy_for(apollo_user(:member)).update?
    assert_not policy_for(apollo_user(:viewer)).update?
  end

  # Matrix row 5 — archive project: owner and admin.
  test "owner and admin may archive the project" do
    assert policy_for(apollo_user(:owner)).archive?
    assert policy_for(apollo_user(:admin)).archive?
    assert_not policy_for(apollo_user(:member)).archive?
    assert_not policy_for(apollo_user(:viewer)).archive?
  end

  # Matrix row 6 — the two irreversible acts. An admin runs the project day to
  # day but cannot hand it away or destroy it; that stays with the one owner.
  test "only the owner may transfer ownership or delete the project" do
    assert policy_for(apollo_user(:owner)).transfer_ownership?
    assert policy_for(apollo_user(:owner)).destroy?

    %i[ admin member viewer ].each do |role|
      policy = policy_for(apollo_user(role))

      assert_not policy.transfer_ownership?, "#{role} should not transfer ownership"
      assert_not policy.destroy?, "#{role} should not delete the project"
    end
  end

  # system_admin creates projects; it is not a skeleton key to the ones it did
  # not create. Stated explicitly because "admin" reads like it should be.
  test "a system admin holds no power over a project they are not a member of" do
    policy = policy_for(users(:admin))

    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  # The scope is the mechanism behind "it never appears in any index" — the
  # filtering is in the query, so no view can forget it.
  test "the scope returns only projects the user is a member of" do
    resolved = ProjectPolicy::Scope.new(apollo_user(:owner), Project.all).resolve

    assert_includes resolved, projects(:apollo)
    assert_includes resolved, projects(:gemini)
    assert_not_includes resolved, projects(:archived)
  end

  # A user in no project sees an empty list rather than an error or everything.
  test "the scope is empty for a user with no memberships" do
    assert_empty ProjectPolicy::Scope.new(non_member, Project.all).resolve
  end
end
