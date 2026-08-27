require "test_helper"

class ProgressTest < ActiveSupport::TestCase
  # Done-count over total-count, exactly as §3 words it. The pair is kept rather
  # than only a percentage because the views print "3 of 7" next to the bar.
  test "reports the counts it was given" do
    progress = Progress.new(done: 3, total: 7)

    assert_equal 3, progress.done
    assert_equal 7, progress.total
    assert_equal "3 of 7", progress.to_s
  end

  test "rounds the percentage to a whole number" do
    assert_equal 43, Progress.new(done: 3, total: 7).percent
    assert_equal 50, Progress.new(done: 1, total: 2).percent
    assert_equal 100, Progress.new(done: 4, total: 4).percent
  end

  # An empty container is the common case — a new epic has no stories — and it
  # must not divide by zero. Zero of zero is nothing done, not everything done.
  test "an empty total is zero percent rather than a division error" do
    empty = Progress.new(done: 0, total: 0)

    assert_equal 0, empty.percent
    assert_not empty.any?
  end

  test "any? is true once there is something to count" do
    assert Progress.new(done: 0, total: 1).any?
  end

  # The bar is drawn from this, so a percentage that could exceed 100 would
  # overflow its track. Complete is complete.
  test "a complete container is exactly one hundred percent" do
    assert_equal 100, Progress.new(done: 9, total: 9).percent
    assert Progress.new(done: 9, total: 9).complete?
    assert_not Progress.new(done: 8, total: 9).complete?
  end

  # An empty container is not complete: there is nothing to have finished.
  test "an empty container is not complete" do
    assert_not Progress.new(done: 0, total: 0).complete?
  end
end
