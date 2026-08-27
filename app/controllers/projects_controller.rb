class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update ]
  before_action :require_system_admin, only: %i[ new create ]
  before_action :require_project_admin, only: %i[ edit update ]

  def index
    @projects = Project.visible_to(Current.user).active.order(:name)
  end

  def show
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

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
    # Scoped through the current user's memberships, so a project they are not in
    # raises RecordNotFound and renders 404 — a non-member never learns it exists.
    def set_project
      @project = Project.visible_to(Current.user).find_by!(slug: params[:id])
    end

    def current_membership
      @current_membership ||= Current.user.memberships.find_by(project: @project)
    end

    def require_project_admin
      head :forbidden unless current_membership&.role&.in?(%w[ owner admin ])
    end

    def require_system_admin
      head :forbidden unless Current.user.system_admin?
    end

    def project_params
      params.expect(project: [ :name, :slug, :description ])
    end
end
