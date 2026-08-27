# A milestone takes the work-item defaults unchanged: matrix row 1 for reading,
# row 3 for changing. The class exists anyway because §4 asks for one policy per
# model — the place to state a milestone-specific rule has to exist before there
# is one to state, or the rule lands in a controller instead.
class MilestonePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(project: Project.visible_to(user))
  end
end
