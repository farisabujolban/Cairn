class Epic < ApplicationRecord
  include WorkItemStatus
  include Progressing

  belongs_to :project
  belongs_to :milestone, optional: true
  has_many :stories, dependent: :destroy

  # §3's progress bar: done stories over total stories. Status stays manual at
  # every level, so this reports what people set rather than rolling anything up.
  progress_over :stories

  normalizes :title, with: ->(t) { t.strip }

  before_validation :append_to_project, on: :create

  validates :title, presence: true
  validates :position, presence: true
  validate :milestone_must_belong_to_the_same_project

  scope :ordered, -> { order(:position, :id) }

  private
    # Positions are numbered per project so one project's backlog length never
    # affects where another project's next epic lands.
    def append_to_project
      self.position ||= (project&.epics&.maximum(:position) || 0) + 1
    end

    # Scheduling stays inside the project. Pointing at another project's
    # milestone would render its title to anyone who can see this epic.
    def milestone_must_belong_to_the_same_project
      return if milestone.nil? || milestone.project_id == project_id

      errors.add(:milestone, "must belong to the same project")
    end
end
