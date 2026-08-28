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

  # §3's progress helper: done stories over total stories. Status is manual at
  # every level, so this counts what people set rather than deriving anything.
  test "progress counts its done stories against all of them" do
    epic = epics(:launch)
    assert_equal Progress.new(done: 0, total: 2), epic.progress

    epic.stories.first.done!

    assert_equal Progress.new(done: 1, total: 2), epic.reload.progress
  end

  # An epic with nothing under it yet is the first thing anyone sees after
  # creating one, so it must report empty rather than divide by zero.
  test "progress on an epic with no stories is empty" do
    epic = Epic.create!(project: projects(:apollo), title: "Empty")

    assert_not epic.progress.any?
    assert_equal 0, epic.progress.percent
  end

  # The backlog tree reads in position order, not insertion order — that is the
  # whole point of storing a position at all.
  test "ordered returns epics by position" do
    ordered = projects(:apollo).epics.ordered.to_a

    assert_equal [ epics(:launch), epics(:telemetry) ], ordered
  end
  # The backlog tree renders three levels from one eager-loaded query, so it
  # cannot call .ordered on a loaded association without re-querying every row.
  # Position order is the only meaningful order for stories under an epic, so it
  # belongs on the association rather than being remembered at each call site.
  test "stories come back in position order without being asked" do
    epic = epics(:launch)

    assert_equal [ stories(:countdown), stories(:abort_switch) ], epic.stories.to_a
  end
  # The backlog tree eager-loads three levels and then asks every row for its
  # progress. Counting that in SQL would be two further queries per row — the
  # exact N+1 the eager load exists to prevent — so an association that is
  # already in memory is counted in memory.
  test "progress counts an already-loaded association without querying again" do
    epic = Epic.includes(:stories).find(epics(:launch).id)

    assert_no_queries do
      assert_equal Progress.new(done: 0, total: 2), epic.progress
    end
  end

  # The unloaded path still counts in SQL: a detail page asking one epic for its
  # progress must not drag every story into memory to answer.
  test "progress counts an unloaded association in the database" do
    assert_equal Progress.new(done: 0, total: 2), epics(:launch).progress
  end
end
