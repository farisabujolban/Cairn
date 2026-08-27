require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  # A user with no name renders as a blank string everywhere they are shown —
  # in an assignee dropdown a nameless option is unpickable, so the name is
  # required rather than decorative.
  test "is invalid without a name" do
    user = User.new(email_address: "nameless@example.com", password: "secret123")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  # Sign-up is disabled, so system_admin is the bootstrap privilege that creates
  # the first user and project. It must never be granted by omission: a record
  # saved without mentioning it has to come back false, not nil.
  test "system_admin defaults to false" do
    user = User.create!(name: "Plain", email_address: "plain@example.com", password: "secret123")
    assert_equal false, user.system_admin
  end

  # Email is the login identifier and the way an admin adds a teammate to a
  # project, so two accounts sharing one address would make sign-in ambiguous.
  # Normalization means the duplicate can differ only in case or whitespace.
  test "is invalid with an email_address already taken in a different case" do
    duplicate = User.new(name: "Copy", email_address: "  ONE@EXAMPLE.COM ", password: "secret123")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  # A session outliving its user is an authentication bypass: the session row is
  # what the cookie resolves to, so it must not survive the account it belongs to.
  test "destroying a user destroys its sessions" do
    user = users(:admin)
    user.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")

    assert_difference -> { Session.count }, -1 do
      user.destroy
    end
  end

  # A user's grants must not outlive the account. A leftover membership row would
  # keep a deleted user counted as a project member.
  test "destroying a user destroys its memberships" do
    user = User.create!(name: "Temp", email_address: "temp@example.com", password: "secret123")
    user.memberships.create!(project: projects(:apollo), role: :viewer)

    assert_difference -> { Membership.count }, -1 do
      user.destroy
    end
  end

  # Deleting the sole owner of a project would orphan it just as surely as
  # demoting them. The cascade must be blocked, not allowed to strip the owner.
  test "cannot be destroyed while sole owner of a project" do
    owner = users(:one)

    assert_no_difference -> { User.count } do
      assert_not owner.destroy
    end
    assert_equal "owner", memberships(:apollo_owner).reload.role
  end
end
