class MembershipsController < ApplicationController
  include ProjectScoped

  before_action :set_membership, only: %i[ update destroy ]

  def index
    @memberships = policy_scope(@project.memberships).by_role.includes(:user)
  end

  def new
    @membership = authorize @project.memberships.new
    @candidates = candidate_users
  end

  def create
    @membership = authorize @project.memberships.new(membership_params)

    if @membership.save
      redirect_to project_memberships_path(@project), notice: "#{@membership.user.name} added."
    else
      @candidates = candidate_users
      render :new, status: :unprocessable_content
    end
  end

  def update
    if transferring_ownership?
      transfer_ownership
    elsif @membership.update(membership_params)
      redirect_to project_memberships_path(@project), notice: "#{@membership.user.name} is now #{@membership.role}."
    else
      redirect_to project_memberships_path(@project), alert: @membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @membership.destroy
      redirect_to project_memberships_path(@project), notice: "#{@membership.user.name} removed."
    else
      redirect_to project_memberships_path(@project), alert: @membership.errors.full_messages.to_sentence
    end
  end

  private
    # Sign-up is disabled, so every account is made by a system admin and this
    # list stays small. People already on the project are left out: choosing one
    # could only fail the uniqueness rule on the user/project pair.
    def candidate_users
      User.where.not(id: @project.memberships.select(:user_id)).order(:name)
    end

    # Looked up through the project rather than globally: pairing one project's
    # path with another project's membership id must resolve to nothing.
    def set_membership
      @membership = authorize @project.memberships.find(params[:id])
    end

    # Choosing "owner" is not a role edit, it is matrix row 6 — so it is
    # authorized against the project rather than against this row. Without the
    # second check an admin, who may edit roles, could promote themselves.
    def transferring_ownership?
      membership_params[:role] == "owner"
    end

    def transfer_ownership
      authorize @project, :transfer_ownership?
      @project.transfer_ownership_to!(@membership.user)

      redirect_to project_memberships_path(@project),
                  notice: "#{@membership.user.name} now owns this project."
    end

    # project_id is deliberately absent: it comes from the path, so an admin of
    # one project cannot grant anyone access to another.
    def membership_params
      params.expect(membership: [ :user_id, :role ])
    end
end
