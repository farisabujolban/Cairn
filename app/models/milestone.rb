class Milestone < ApplicationRecord
  include Progressing

  # A milestone is a flat, dated bucket rather than a level of the Epic → Story
  # → Task tree, so it has exactly two states: still collecting work, or shipped.
  STATES = %w[ open closed ].freeze

  belongs_to :project
  # Nullify, not destroy: a cancelled or renamed ship date must not take the
  # work planned against it with it. The epic survives, unscheduled.
  has_many :epics, dependent: :nullify
  # Stories reference a milestone directly too: the scheduling axis reaches both
  # levels, and losing the date must not lose the story either.
  has_many :stories, dependent: :nullify

  # What the milestone list answers: how much of the work promised for this date
  # is finished. Two routes reach a milestone — a story scheduled against it
  # directly, and a story inside an epic scheduled against it — and a story
  # taking both must be counted once, which is why this is one OR'd query rather
  # than two counts added together.
  progress_over :scheduled_stories

  enum :state, STATES.index_by(&:itself), validate: { allow_nil: true }

  normalizes :title, with: ->(t) { t.strip }

  validates :title, presence: true
  validates :state, presence: true

  # Undated milestones sort after dated ones: "someday" is not due before the
  # release two weeks out, which is what SQLite's NULLs-first default would say.
  def scheduled_stories
    Story.where(epic: epics).or(Story.where(milestone: self))
  end

  scope :by_due_date, -> { order(arel_table[:due_on].asc.nulls_last, :title) }
end
