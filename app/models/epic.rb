class Epic < ApplicationRecord
  # One status vocabulary across every work-item level, ordered from unsorted to
  # finished. Story and Task share it.
  STATUSES = %w[ backlog todo in_progress blocked done ].freeze

  belongs_to :project
  belongs_to :milestone, optional: true
  has_many :stories, dependent: :destroy

  enum :status, STATUSES.index_by(&:itself), validate: { allow_nil: true }

  normalizes :title, with: ->(t) { t.strip }

  before_validation :append_to_project, on: :create

  validates :title, presence: true
  validates :status, presence: true
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
