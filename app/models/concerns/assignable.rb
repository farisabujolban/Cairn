# The two levels people pick work up at — Story and Task. An epic is a
# container rather than something one person holds, so it is not assignable.
#
# Assignment follows project membership, and the check lives here rather than
# on each model so there is one answer to who may hold work: handing a task to
# a non-member would print their name on a project page they cannot open, and
# give them work they cannot see.
module Assignable
  extend ActiveSupport::Concern

  included do
    belongs_to :assignee, class_name: "User", optional: true

    validate :assignee_must_be_a_project_member
  end

  private
    def assignee_must_be_a_project_member
      return if assignee.nil? || project.nil?
      return if project.memberships.exists?(user_id: assignee.id)

      errors.add(:assignee, "must be a member of this project")
    end
end
