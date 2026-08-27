class MilestonesController < ApplicationController
  before_action :set_project
  before_action :set_milestone, only: %i[ show edit update destroy ]
  before_action :require_contributor, only: %i[ new create edit update destroy ]

  helper_method :contributor?

  def index
    @milestones = @project.milestones.by_due_date
  end

  def show
  end

  def new
    @milestone = @project.milestones.new
  end

  def create
    @milestone = @project.milestones.new(milestone_params)

    if @milestone.save
      redirect_to project_milestones_path(@project), notice: "Milestone created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @milestone.update(milestone_params)
      redirect_to project_milestone_path(@project, @milestone), notice: "Milestone updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @milestone.destroy

    redirect_to project_milestones_path(@project), notice: "Milestone deleted."
  end

  private
    # Scoped through the current user's memberships, so a project they are not in
    # raises RecordNotFound and renders 404 — a non-member never learns it exists.
    def set_project
      @project = Project.visible_to(Current.user).find(params[:project_id])
    end

    # Looked up through the project rather than globally: pairing one project's
    # path with another project's milestone id must resolve to nothing.
    def set_milestone
      @milestone = @project.milestones.find(params[:id])
    end

    def current_membership
      @current_membership ||= Current.user.memberships.find_by(project: @project)
    end

    # The §4 matrix puts milestone changes at member level: ordinary project
    # work, not administration. Views ask the same question so a viewer is not
    # shown buttons that would only 403.
    def contributor?
      current_membership&.role&.in?(%w[ owner admin member ]) || false
    end

    # A viewer gets 403 rather than 404: they already know the project exists,
    # so hiding it would only confuse.
    def require_contributor
      head :forbidden unless contributor?
    end

    # project_id is deliberately absent: it comes from the path, so a member of
    # one project cannot plant a milestone inside another.
    def milestone_params
      params.expect(milestone: [ :title, :description, :due_on, :state ])
    end
end
