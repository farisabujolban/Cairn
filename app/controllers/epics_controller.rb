class EpicsController < ApplicationController
  include ProjectScoped
  include InlineStatus

  before_action :set_epic, only: %i[ show edit update destroy ]

  def index
    @epics = policy_scope(@project.epics).ordered
  end

  def show
  end

  def new
    @epic = authorize @project.epics.new
  end

  def create
    @epic = authorize @project.epics.new(epic_params)

    if @epic.save
      redirect_to project_epic_path(@project, @epic), notice: "Epic created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    saved = @epic.update(epic_params)
    # The backlog tree's inline change lands here too, and answers with the one
    # control rather than a redirect. See InlineStatus.
    return if rendered_status_frame?(@epic, saved)

    if saved
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
    # path with another project's epic id must resolve to nothing. The policy
    # then answers the role question on the record that was found.
    def set_epic
      @epic = authorize @project.epics.find(params[:id])
    end

    # milestone_id is permitted because the form sets it, but Epic validates
    # that the milestone belongs to this project — a foreign id is rejected
    # rather than silently stored.
    def epic_params
      params.expect(epic: [ :title, :description, :status, :milestone_id ])
    end
end
