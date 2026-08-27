class Task < ApplicationRecord
  include WorkItemStatus
  include Assignable

  # A Task is a leaf. There is no has_many here, no parent_id on the table, and
  # no self-referential association — see §6. If a task needs children, the work
  # it describes is a Story.
  belongs_to :story

  delegate :project, to: :story, allow_nil: true

  normalizes :title, with: ->(t) { t.strip }

  before_validation :append_to_story, on: :create

  validates :title, presence: true
  validates :position, presence: true

  scope :ordered, -> { order(:position, :id) }

  private
    # Positions are numbered per story so one story's checklist never affects
    # where another story's next task lands.
    def append_to_story
      self.position ||= (story&.tasks&.maximum(:position) || 0) + 1
    end
end
