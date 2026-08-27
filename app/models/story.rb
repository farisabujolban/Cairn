class Story < ApplicationRecord
  include WorkItemStatus
  include Progressing
  include Assignable

  belongs_to :epic
  belongs_to :milestone, optional: true
  has_many :tasks, dependent: :destroy

  # Done tasks over total tasks. A story at 100% is still only done when someone
  # says so: §3 rules out rollup in v1.
  progress_over :tasks

  # Reached through the epic rather than stored again: containment already
  # answers which project this is in, and a second copy could disagree with it.
  delegate :project, to: :epic, allow_nil: true

  normalizes :title, with: ->(t) { t.strip }

  before_validation :append_to_epic, on: :create

  validates :title, presence: true
  validates :position, presence: true
  validate :milestone_must_belong_to_the_same_project

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
end
