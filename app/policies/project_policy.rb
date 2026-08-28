# Matrix rows 1, 5 and 6, plus the one privilege that is not a project role at
# all: creating projects.
class ProjectPolicy < ApplicationPolicy
  # There is no project in hand on the index, so there is no role to hold over
  # one. Everyone signed in may ask; the scope decides what comes back.
  def index? = true

  # Sign-up is disabled, so someone has to be able to create the first project
  # before any membership exists to authorize it. That is what system_admin is
  # for, and it is the whole of what it is for — see the show? row below, which
  # a system admin fails like anyone else.
  def create? = user&.system_admin? || false

  # Renaming or re-describing the project is administration of the project
  # rather than work inside it, so it sits with archiving rather than with
  # epics and stories.
  def update? = administrator?

  # Matrix row 5. Archiving hides the project from the active listing; it is
  # recoverable, which is why an admin may do it and deleting stays below.
  def archive? = administrator?

  # The other half of row 5 rather than a row of its own. Archiving is only
  # reversible if the people who can do it can also undo it; splitting these
  # would turn the archive into the one-way trip the archived listing exists to
  # prevent.
  def restore? = archive?

  # Matrix row 6. Both of these can leave the team without a project or without
  # a way back into one, so they stop at the single owner.
  def transfer_ownership? = owner?
  def destroy? = owner?

  # Membership, not existence, is what makes a project visible. Everything the
  # app lists is filtered through this, directly or by reaching a project.
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.merge(Project.visible_to(user))
  end
end
