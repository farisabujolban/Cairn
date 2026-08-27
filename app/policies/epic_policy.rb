# An epic takes the work-item defaults unchanged: matrix row 1 for reading,
# row 2 for changing.
class EpicPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(project: Project.visible_to(user))
  end
end
