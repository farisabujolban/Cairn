# A story takes the work-item defaults unchanged: matrix row 1 for reading,
# row 2 for changing.
class StoryPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # Two hops, because a story has no project_id of its own — the same
    # containment path Story#project delegates along.
    def resolve = scope.where(epic: Epic.where(project: Project.visible_to(user)))
  end
end
