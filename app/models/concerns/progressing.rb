# Progress is always the same question — how many of the things under this one
# are done — asked of a different collection at each level. The collection is
# named by the including model; the counting lives here once.
module Progressing
  extend ActiveSupport::Concern

  class_methods do
    def progress_over(association)
      define_method :progress do
        scope = public_send(association)

        Progress.new(done: scope.done.count, total: scope.count)
      end
    end
  end
end
