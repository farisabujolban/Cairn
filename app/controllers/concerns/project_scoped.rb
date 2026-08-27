# Shared by every controller whose records live inside a project.
#
# The project is looked up through the same scope ProjectPolicy::Scope resolves
# to, so a non-member's request raises RecordNotFound and renders 404 without
# ever reaching a policy — they never learn the project exists.
#
# It is deliberately *not* `authorize @project` here. Pundit's verify_authorized
# is satisfied by any single authorize call in the request, so authorizing the
# project would quietly excuse an action that forgot to authorize its own epic
# or task. Scoping the lookup instead leaves that guarantee intact, and leaves
# the project's own visibility enforced in the query rather than after it.
#
# What this concern no longer does is answer role questions. It used to carry a
# second copy of the §4 matrix — a contributor? helper the controllers and views
# both consulted — and that copy is what the policies replaced.
module ProjectScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_project
  end

  private
    def set_project
      @project = Project.visible_to(Current.user).find(params[:project_id])
    end
end
