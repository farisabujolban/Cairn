# Shared by every controller whose records live inside a project.
#
# The scoping is the authorization: looking the project up through the current
# user's memberships means a non-member's request raises RecordNotFound and
# renders 404, so they never learn the project exists. Phase 4 replaces this
# with Pundit policies; until then it is duplicated nowhere else.
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

    def current_membership
      @current_membership ||= Current.user.memberships.find_by(project: @project)
    end

    # The §4 matrix puts epic, story, task and milestone changes at member
    # level: ordinary project work, not administration. Views ask the same
    # question so a viewer is not shown buttons that would only 403.
    def contributor?
      current_membership&.role&.in?(%w[ owner admin member ]) || false
    end

    # A viewer gets 403 rather than 404: they already know the project exists,
    # so hiding it would only confuse.
    def require_contributor
      head :forbidden unless contributor?
    end
end
