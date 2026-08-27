# Done-count over total-count, per §3, as a value rather than a pair of numbers
# passed around loose. Epic, Story and Milestone all answer with one of these,
# so the progress bar partial does not care which level it is drawing.
Progress = Data.define(:done, :total) do
  # An empty container — a new epic, an unplanned milestone — is nothing done
  # rather than everything done, and must not divide by zero.
  def percent = any? ? (done * 100.0 / total).round : 0

  def any? = total.positive?

  def complete? = any? && done == total

  def to_s = "#{done} of #{total}"
end
