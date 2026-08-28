class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :projects, through: :memberships
  # Nullify, not destroy: removing a person must not delete the work they were
  # holding. It goes back to unassigned.
  has_many :assigned_stories, class_name: "Story", foreign_key: :assignee_id, dependent: :nullify, inverse_of: :assignee
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, dependent: :nullify, inverse_of: :assignee

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true

  # The role this user holds in one project, which is the only question every
  # policy in §4 ever asks. Cached per user instance because the backlog tree
  # builds one policy per row: without this the screen with the most rows in the
  # app runs a membership query for each of them, which is the N+1 the tree's
  # eager loading exists to prevent arriving through authorization instead.
  #
  # A user instance lives for one request, so the cache cannot outlast a role
  # change — every screen that changes one redirects, and the next request
  # starts with a fresh user.
  #
  # Misses are cached too. Storing only the hits would leave every row belonging
  # to a project the user is not in querying on each ask, which is the same N+1
  # wearing a different hat.
  def membership_in(project)
    return nil unless project&.persisted?

    @membership_by_project ||= {}
    return @membership_by_project[project.id] if @membership_by_project.key?(project.id)

    @membership_by_project[project.id] = memberships.find_by(project: project)
  end
end
