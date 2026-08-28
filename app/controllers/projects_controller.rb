class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update archive restore destroy ]

  # One listing with two positions rather than two screens. The parameter names
  # a scope, so only these two may be named: anything else falls back to the
  # live list rather than reaching the model.
  def index
    @showing_archived = params[:status] == "archived"
    scope = policy_scope(Project)

    @projects = (@showing_archived ? scope.archived : scope.active).order(:name)
  end

  def show
  end

  def new
    @project = authorize Project.new
  end

  def create
    @project = authorize Project.new(project_params)

    Project.transaction do
      @project.save!
      # A project with no owner can never be transferred or deleted, so the
      # owning membership is created in the same transaction as the project.
      @project.memberships.create!(user: Current.user, role: :owner)
    end

    redirect_to @project, notice: "Project created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Matrix row 5. The redirect lands on the archived listing rather than the
  # active one the project just left: the person who archived it sees where it
  # went, and that Restore is sitting next to it. Archiving is only reversible
  # if the way back is discoverable.
  def archive
    @project.archive!

    redirect_to projects_path(status: "archived"), notice: "#{@project.name} archived."
  end

  def restore
    @project.restore!

    redirect_to @project, notice: "#{@project.name} restored."
  end

  # Matrix row 6, and the route that has resolved to a 404 since phase 1: DELETE
  # was routed with no action behind it. destroy! rather than destroy because a
  # cascade that silently refuses would redirect with a success notice.
  def destroy
    @project.destroy!

    redirect_to projects_path, notice: "#{@project.name} deleted."
  end

  private
    # Found globally and then authorized, rather than scoped to the user's
    # memberships: the policy is the single source of truth for who may see
    # this, and deny_access turns a non-member's refusal into the same 404 the
    # scoped lookup used to raise.
    def set_project
      @project = authorize Project.find(params[:id])
    end

    def project_params
      params.expect(project: [ :name, :slug, :description ])
    end
end
