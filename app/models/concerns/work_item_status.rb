# The one status vocabulary, shared by every level of the Epic → Story → Task
# tree. It lives here rather than on each model so the three cannot drift: a
# status added to one level is added to all of them, and the backlog view can
# place any row in a column without asking what kind of row it is.
module WorkItemStatus
  extend ActiveSupport::Concern

  # Ordered from unsorted to finished. The forms render select options straight
  # from this order.
  STATUSES = %w[ backlog todo in_progress blocked done ].freeze

  included do
    enum :status, STATUSES.index_by(&:itself), validate: { allow_nil: true }

    # allow_nil above lets a blank through the enum's own check so that it is
    # reported as the ordinary "can't be blank" rather than an unknown value.
    validates :status, presence: true
  end
end
