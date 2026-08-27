class Story < ApplicationRecord
  # The same vocabulary Epic uses; Task joins it below. Extracted into a shared
  # concern once all three levels exist.
  STATUSES = Epic::STATUSES

  belongs_to :epic
  belongs_to :milestone, optional: true
  belongs_to :assignee, class_name: "User", optional: true

  # Reached through the epic rather than stored again: containment already
  # answers which project this is in, and a second copy could disagree with it.
  delegate :project, to: :epic, allow_nil: true

  enum :status, STATUSES.index_by(&:itself), validate: { allow_nil: true }

  normalizes :title, with: ->(t) { t.strip }

  before_validation :append_to_epic, on: :create

  validates :title, presence: true
  validates :status, presence: true
  validates :position, presence: true
  validate :milestone_must_belong_to_the_same_project
  validate :assignee_must_be_a_project_member

  scope :ordered, -> { order(:position, :id) }

  private
    # Positions are numbered per epic so one epic's length never affects where
    # another epic's next story lands.
    def append_to_epic
      self.position ||= (epic&.stories&.maximum(:position) || 0) + 1
    end

    # Scheduling stays inside the project. Pointing at another project's
    # milestone would render its title to anyone who can see this story.
    def milestone_must_belong_to_the_same_project
      return if milestone.nil? || milestone.project_id == project&.id

      errors.add(:milestone, "must belong to the same project")
    end

    # Assignment follows membership: handing work to a non-member would print
    # their name on a project page they cannot open.
    def assignee_must_be_a_project_member
      return if assignee.nil? || project.nil?
      return if project.memberships.exists?(user_id: assignee.id)

      errors.add(:assignee, "must be a member of this project")
    end
end
