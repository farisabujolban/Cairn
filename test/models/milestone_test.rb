require "test_helper"

class MilestoneTest < ActiveSupport::TestCase
  # A milestone is a dated bucket users pick from a list; an untitled one is
  # indistinguishable from every other untitled one at the point of choosing.
  test "is invalid without a title" do
    milestone = Milestone.new(project: projects(:apollo), title: "")
    assert_not milestone.valid?
    assert_includes milestone.errors[:title], "can't be blank"
  end

  # Milestones are scoped per project, never global. A projectless milestone
  # could be attached to an epic in a project the user cannot even see.
  test "is invalid without a project" do
    milestone = Milestone.new(title: "Orphan")
    assert_not milestone.valid?
    assert_includes milestone.errors[:project], "must exist"
  end

  # A milestone is open until someone closes it. Requiring the state to be set
  # on create would make every call site repeat the same literal.
  test "is open when created without an explicit state" do
    milestone = Milestone.create!(project: projects(:apollo), title: "Unstated")
    assert milestone.open?
  end

  # The state vocabulary is exactly two values. Anything else reaching the
  # column would make "is this milestone finished?" unanswerable.
  test "rejects a state outside the open/closed vocabulary" do
    milestone = Milestone.new(project: projects(:apollo), title: "Bad state", state: "shipped")
    assert_not milestone.valid?
    assert_includes milestone.errors[:state], "is not included in the list"
  end

  # Closing is the one transition the UI offers, and it must persist rather than
  # only flip the in-memory attribute.
  test "closed! moves an open milestone to closed" do
    milestone = milestones(:v1)
    milestone.closed!

    assert milestone.reload.closed?
    assert_includes Milestone.closed, milestone
    assert_not_includes Milestone.open, milestone
  end

  # The milestone list is a schedule, so it reads in ship order rather than
  # creation order — otherwise the next thing due is not the first thing shown.
  test "by_due_date orders milestones by their due date" do
    ordered = projects(:apollo).milestones.by_due_date.to_a

    assert_equal [ milestones(:v1), milestones(:v2) ], ordered.first(2)
  end

  # A milestone with no date is not due before everything else. Sorting NULLs
  # first is SQLite's default and would put undated work at the top of a
  # schedule, which is precisely backwards.
  test "by_due_date sorts undated milestones after dated ones" do
    ordered = projects(:apollo).milestones.by_due_date.to_a

    assert_equal milestones(:undated), ordered.last
  end

  # A ship date can be cancelled or renamed without the work planned against it
  # ceasing to exist. Destroying the milestone must unschedule its epics, not
  # delete them — the opposite of the project cascade.
  test "destroying a milestone unschedules its epics instead of destroying them" do
    assert_no_difference -> { Epic.count } do
      milestones(:v1).destroy
    end

    assert_nil epics(:launch).reload.milestone_id
  end
  # What the milestone list shows: how much of the work promised for this date
  # is finished. Stories are the unit counted because that is what "how much of
  # v1.1 is done" means to the person reading the list.
  #
  # Two routes reach a milestone — a story scheduled against it directly, and a
  # story inside an epic scheduled against it — and a story taking both must be
  # counted once, not twice.
  test "progress counts the stories scheduled against it, directly or through an epic" do
    milestone = milestones(:v1)

    # launch (the epic) is on v1 and holds two stories, one of which — countdown —
    # is also scheduled against v1 in its own right.
    assert_equal Progress.new(done: 0, total: 2), milestone.progress

    stories(:countdown).done!

    assert_equal Progress.new(done: 1, total: 2), milestone.reload.progress
  end

  # A date nobody has planned work against yet reports empty rather than
  # dividing by zero, exactly as an epic with no stories does.
  test "progress on a milestone with nothing scheduled is empty" do
    assert_not milestones(:undated).progress.any?
  end
end
