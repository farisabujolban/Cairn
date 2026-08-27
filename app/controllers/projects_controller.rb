class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update ]

  def index
    @projects = policy_scope(Project).active.order(:name)
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
