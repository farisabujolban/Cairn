# Progress is always the same question — how many of the things under this one
# are done — asked of a different collection at each level. The collection is
# named by the including model; the counting lives here once.
module Progressing
  extend ActiveSupport::Concern

  class_methods do
    def progress_over(association)
      define_method :progress do
        scope = public_send(association)

        # An association the caller already eager-loaded is counted in memory.
        # The backlog tree renders three levels from one query and then asks
        # every row for its progress; counting in SQL there would be two more
        # queries per row — the exact N+1 the eager load exists to prevent.
        #
        # Unloaded, it still counts in SQL: a detail page asking one epic for
        # its progress must not drag every story into memory to answer.
        if scope.loaded?
          records = scope.to_a

          Progress.new(done: records.count(&:done?), total: records.size)
        else
          Progress.new(done: scope.done.count, total: scope.count)
        end
      end
    end
  end
end
