class EpicsController < ApplicationController
  include ProjectScoped

  before_action :set_epic, only: %i[ show edit update destroy ]
  before_action :require_contributor, only: %i[ new create edit update destroy ]

  def index
    @epics = @project.epics.ordered
  end

  def show
  end

  def new
    @epic = @project.epics.new
  end

  def create
    @epic = @project.epics.new(epic_params)

    if @epic.save
      redirect_to project_epic_path(@project, @epic), notice: "Epic created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @epic.update(epic_params)
      redirect_to project_epic_path(@project, @epic), notice: "Epic updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @epic.destroy

    redirect_to project_epics_path(@project), notice: "Epic deleted."
  end

  private
    # Looked up through the project rather than globally: pairing one project's
    # path with another project's epic id must resolve to nothing.
    def set_epic
      @epic = @project.epics.find(params[:id])
    end

    # milestone_id is permitted because the form sets it, but Epic validates
    # that the milestone belongs to this project — a foreign id is rejected
    # rather than silently stored.
    def epic_params
      params.expect(epic: [ :title, :description, :status, :milestone_id ])
    end
end
