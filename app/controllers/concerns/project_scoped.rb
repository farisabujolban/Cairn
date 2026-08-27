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
module ProjectScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_project

    helper_method :contributor?
  end

  private
    def set_project
      @project = Project.visible_to(Current.user).find(params[:project_id])
    end

    # A second copy of the §4 matrix, which is exactly what this phase exists to
    # delete. It is retired one controller at a time as each gains its policy;
    # the last controller to stop calling it takes these three methods with it.
    def current_membership
      @current_membership ||= Current.user.memberships.find_by(project: @project)
    end

    def contributor?
      current_membership&.role&.in?(%w[ owner admin member ]) || false
    end

    def require_contributor
      head :forbidden unless contributor?
    end
end
