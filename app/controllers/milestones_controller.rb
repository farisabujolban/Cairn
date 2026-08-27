class MilestonesController < ApplicationController
  include ProjectScoped

  before_action :set_milestone, only: %i[ show edit update destroy ]
  before_action :require_contributor, only: %i[ new create edit update destroy ]

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
    # Looked up through the project rather than globally: pairing one project's
    # path with another project's milestone id must resolve to nothing.
    def set_milestone
      @milestone = @project.milestones.find(params[:id])
    end

    # project_id is deliberately absent: it comes from the path, so a member of
    # one project cannot plant a milestone inside another.
    def milestone_params
      params.expect(milestone: [ :title, :description, :due_on, :state ])
    end
end
