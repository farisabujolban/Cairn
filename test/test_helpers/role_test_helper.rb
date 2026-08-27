# The §4 matrix is a table, and the tests that pin it read as one. Apollo holds
# a user in every role, so a policy test can iterate the columns rather than
# repeating the same four-fold setup in each file.
module RoleTestHelper
  APOLLO_ROLES = { owner: :one, admin: :three, member: :four, viewer: :two }.freeze

  # A user who is a member of no project at all. system_admin is deliberate: it
  # proves the bootstrap privilege grants no access to anyone's content.
  def non_member = users(:admin)

  def apollo_user(role) = users(APOLLO_ROLES.fetch(role))

  # Yields each role paired with the user holding it, so a matrix row is one
  # loop and a failure names the role that broke.
  def each_apollo_role
    APOLLO_ROLES.each_key { |role| yield role, apollo_user(role) }
  end
end
