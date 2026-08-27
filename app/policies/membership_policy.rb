# Matrix row 4 — add & remove members, assign roles — plus the two edge cases
# §4 names, both of which are about protecting the owner.
class MembershipPolicy < ApplicationPolicy
  # Deliberately every role, and not in the matrix. Seeing who is on the project
  # is part of viewing it: assignee names already appear on every story and task
  # a viewer can open, so hiding the roster would conceal nothing while making
  # it impossible to know who to ask about a piece of work.
  def index? = member?
  def show? = member?

  # Ownership arrives with the project or moves by transfer. A membership that
  # is already the owner sidesteps both, and the one-owner rule with them.
  def create? = administrator? && !record.owner?

  # The owner's own membership is off limits to everyone, including the owner.
  #
  # For an admin this is §4's "an admin cannot demote or remove the owner" —
  # without it, an admin could take the project from the person who owns it.
  # For the owner it is "the last owner cannot be demoted or removed": exactly
  # one owner exists at a time, so the owner's row is always the last one, and
  # changing it directly would leave nobody able to transfer or delete the
  # project. Transfer is the sanctioned way out, and it is its own action on
  # ProjectPolicy rather than an edit to this row.
  def update? = administrator? && !record.owner?
  def destroy? = update?

  # What the role menu may offer. The view asks the policy rather than rendering
  # the enum's values, so a control is never shown that the request behind it
  # would refuse.
  def assignable_roles
    transferable? ? Membership::ROLES : Membership::ROLES - %w[ owner ]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(project: Project.visible_to(user))
  end

  private
    # Choosing "owner" for an existing member *is* the transfer, which matrix
    # row 6 reserves for the owner. It is withheld on a new membership because
    # transferring to somebody not yet on the project would skip the step where
    # they are given access at all.
    def transferable?
      record.persisted? && ProjectPolicy.new(user, record.project).transfer_ownership?
    end
end
