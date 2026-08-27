class Task < ApplicationRecord
  include WorkItemStatus

  # A Task is a leaf. There is no has_many here, no parent_id on the table, and
  # no self-referential association — see §6. If a task needs children, the work
  # it describes is a Story.
  belongs_to :story
  belongs_to :assignee, class_name: "User", optional: true

  delegate :project, to: :story, allow_nil: true

  normalizes :title, with: ->(t) { t.strip }

  before_validation :append_to_story, on: :create

  validates :title, presence: true
  validates :position, presence: true
  validate :assignee_must_be_a_project_member

  scope :ordered, -> { order(:position, :id) }

  private
    # Positions are numbered per story so one story's checklist never affects
    # where another story's next task lands.
    def append_to_story
      self.position ||= (story&.tasks&.maximum(:position) || 0) + 1
    end

    # Assignment follows membership: handing work to a non-member would print
    # their name on a project page they cannot open.
    def assignee_must_be_a_project_member
      return if assignee.nil? || project.nil?
      return if project.memberships.exists?(user_id: assignee.id)

      errors.add(:assignee, "must be a member of this project")
    end
end
