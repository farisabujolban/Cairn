require "test_helper"

class EpicTest < ActiveSupport::TestCase
  # An epic is the top level of the backlog tree and is picked from a list; an
  # untitled one cannot be told apart from any other.
  test "is invalid without a title" do
    epic = Epic.new(project: projects(:apollo), title: "")
    assert_not epic.valid?
    assert_includes epic.errors[:title], "can't be blank"
  end

  # Containment starts at the project. A projectless epic would sit outside
  # every membership scope, which is to say outside authorization entirely.
  test "is invalid without a project" do
    epic = Epic.new(title: "Orphan")
    assert_not epic.valid?
    assert_includes epic.errors[:project], "must exist"
  end

  # The two axes are independent: containment is Project → Epic, scheduling is
  # the milestone. Requiring a ship date to file work would collapse them.
  test "is valid without a milestone" do
    epic = Epic.new(project: projects(:apollo), title: "Unscheduled")
    assert epic.valid?
    assert_nil epic.milestone
  end

  # Scheduling must not cross project boundaries: an epic pointing at another
  # project's milestone would render that milestone's title to someone who may
  # not be a member of the project it belongs to.
  test "is invalid with a milestone from a different project" do
    epic = Epic.new(project: projects(:apollo), title: "Cross-wired", milestone: milestones(:gemini_v1))
    assert_not epic.valid?
    assert_includes epic.errors[:milestone], "must belong to the same project"
  end

  # New work arrives unsorted rather than ready to start, so the default is the
  # backlog end of the vocabulary and not the todo column.
  test "is in the backlog when created without an explicit status" do
    epic = Epic.create!(project: projects(:apollo), title: "Fresh")
    assert epic.backlog?
  end

  # One status vocabulary is shared by every work-item level. A value outside it
  # would make the backlog view unable to place the row in any column.
  test "rejects a status outside the shared vocabulary" do
    epic = Epic.new(project: projects(:apollo), title: "Bad status", status: "shipped")
    assert_not epic.valid?
    assert_includes epic.errors[:status], "is not included in the list"
  end

  # Status is set by hand at every level — §3 rules out automatic rollup — so a
  # transition must simply persist what the user chose.
  test "status moves through the vocabulary and persists" do
    epic = epics(:launch)
    epic.in_progress!

    assert epic.reload.in_progress?
    assert_includes Epic.in_progress, epic
  end

  # Position is what the backlog tree orders by, so it is assigned on create
  # rather than left null: a null would sort unpredictably against integers.
  test "appends new epics to the end of their project's order" do
    epic = Epic.create!(project: projects(:apollo), title: "Latest")

    assert_equal projects(:apollo).epics.maximum(:position), epic.position
    assert_operator epic.position, :>, epics(:launch).position
  end

  # Ordering is per project: the first epic of one project must not be pushed
  # down the list by unrelated epics in another.
  test "numbers positions independently in each project" do
    epic = Epic.create!(project: projects(:archived), title: "First here")

    assert_equal 1, epic.position
  end

  # The backlog tree reads in position order, not insertion order — that is the
  # whole point of storing a position at all.
  test "ordered returns epics by position" do
    ordered = projects(:apollo).epics.ordered.to_a

    assert_equal [ epics(:launch), epics(:telemetry) ], ordered
  end
end
