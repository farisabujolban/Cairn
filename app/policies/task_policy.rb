# A task takes the work-item defaults unchanged: matrix row 1 for reading,
# row 2 for changing.
class TaskPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # Three hops — task to story to epic to project — and §6 guarantees there
    # will never be a fourth, because a task is a leaf.
    def resolve
      scope.where(story: Story.where(epic: Epic.where(project: Project.visible_to(user))))
    end
  end
end
