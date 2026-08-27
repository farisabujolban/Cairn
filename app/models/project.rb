class Project < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :milestones, dependent: :destroy
  has_many :epics, dependent: :destroy

  normalizes :name, with: ->(n) { n.strip }

  before_validation :derive_slug_from_name, on: :create
  after_validation :report_derived_slug_errors_on_name

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: SLUG_FORMAT, message: "must be lowercase letters, numbers and hyphens", allow_blank: true }

  # Membership, not existence, is what makes a project visible. Every listing
  # goes through here (and through Pundit's scope on top of it) so that a
  # non-member never learns the project exists.
  scope :visible_to, ->(user) { where(id: Membership.where(user: user).select(:project_id)) }
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def archived? = archived_at.present?

  # The only sanctioned way past the one-owner rule. Both halves run in one
  # transaction so the project is never left with two owners or none.
  def transfer_ownership_to!(user)
    transaction do
      incoming = memberships.find_by!(user: user)
      outgoing = memberships.owner.first

      outgoing.update!(role: :admin, transferring_ownership: true) if outgoing && outgoing != incoming
      incoming.update!(role: :owner)
    end
  end

  private
    def derive_slug_from_name
      return if slug.present?

      self.slug = name.to_s.parameterize
      @slug_derived = true
    end

    # A derived slug is never a field on the form, so an error on it names
    # something the user cannot see or correct. Re-point those messages at the
    # name they were derived from.
    def report_derived_slug_errors_on_name
      return unless @slug_derived
      return if errors[:slug].empty?

      taken = errors[:slug].any? { |message| message.include?("taken") }
      errors.delete(:slug)

      if taken
        errors.add(:name, "has already been taken")
      elsif name.present?
        # "!!!" parameterizes to "", leaving the slug blank while the name is not.
        errors.add(:name, "must contain at least one letter or number")
      end
      # A blank name already reports itself; the blank slug that follows it adds nothing.
    end
end
