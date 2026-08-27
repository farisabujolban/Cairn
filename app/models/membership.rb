class Membership < ApplicationRecord
  # The permission matrix in §4 of the spec is keyed on exactly these four roles,
  # ordered most to least privileged.
  ROLES = %w[ owner admin member viewer ].freeze

  belongs_to :user
  belongs_to :project

  enum :role, ROLES.index_by(&:itself), validate: { allow_nil: true }

  # Set only by Project#transfer_ownership_to!, which demotes the outgoing owner
  # and promotes the incoming one inside a single transaction.
  attr_accessor :transferring_ownership

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :project_id }
  validate :owner_must_be_unique_within_project
  validate :last_owner_must_stay_owner, on: :update

  before_destroy :refuse_to_remove_last_owner

  # ROLES is ordered by privilege, so the position in it is the sort key. The
  # column stores strings, and ordering on those directly gives admin, member,
  # owner, viewer — the owner third, which reads as noise rather than hierarchy.
  #
  # Built from the frozen ROLES constant, never from input, and plain SQL CASE
  # rather than anything SQLite-specific, so the Postgres swap in §2 stays open.
  ROLE_RANK = ROLES.each_with_index.map { |role, rank| "WHEN '#{role}' THEN #{rank}" }.join(" ").freeze

  scope :by_role, -> {
    joins(:user)
      .order(Arel.sql("CASE memberships.role #{ROLE_RANK} ELSE #{ROLES.size} END"))
      .merge(User.order(:name))
  }

  private
    def owner_must_be_unique_within_project
      return unless owner? && project_id?

      other_owners = Membership.where(project_id: project_id, role: :owner).where.not(id: id)
      return unless other_owners.exists?

      errors.add(:role, "is already held by another member of this project")
    end

    def last_owner_must_stay_owner
      return if transferring_ownership
      return unless role_previously_was_owner? && !owner?
      return if project.memberships.owner.where.not(id: id).exists?

      errors.add(:role, "cannot be changed while this is the project's only owner")
    end

    def role_previously_was_owner?
      role_changed? && role_was == "owner"
    end

    def refuse_to_remove_last_owner
      return unless owner?
      # Deleting the whole project legitimately takes its owner with it. Only a
      # membership removed on its own — or with the user account — can orphan it.
      return if destroyed_by_association&.foreign_key.to_s == "project_id"
      return if project.memberships.owner.where.not(id: id).exists?

      errors.add(:base, "The project's only owner cannot be removed")
      throw :abort
    end
end
