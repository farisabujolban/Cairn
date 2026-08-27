require "test_helper"

class StoryTest < ActiveSupport::TestCase
  # A story is the unit people talk about in planning; an untitled one cannot be
  # referred to at all.
  test "is invalid without a title" do
    story = Story.new(epic: epics(:launch), title: "")
    assert_not story.valid?
    assert_includes story.errors[:title], "can't be blank"
  end

  # Containment is Epic → Story → Task. A story with no epic would sit outside
  # the tree, and so outside every project membership scope that guards it.
  test "is invalid without an epic" do
    story = Story.new(title: "Orphan")
    assert_not story.valid?
    assert_includes story.errors[:epic], "must exist"
  end

  # Scheduling and assignment are both optional: work gets written down before
  # anyone commits to a ship date or picks it up.
  test "is valid without a milestone or an assignee" do
    story = Story.new(epic: epics(:launch), title: "Unscheduled")

    assert story.valid?
    assert_nil story.milestone
    assert_nil story.assignee
  end

  # The project is reached through the epic rather than stored again, so there
  # is one answer to "which project is this in" and it cannot drift.
  test "belongs to its epic's project" do
    assert_equal projects(:apollo), stories(:countdown).project
  end

  # Same leak the Epic guards: a story pointing at another project's milestone
  # would print that milestone's title to someone who may not be a member there.
  test "is invalid with a milestone from a different project" do
    story = Story.new(epic: epics(:launch), title: "Cross-wired", milestone: milestones(:gemini_v1))

    assert_not story.valid?
    assert_includes story.errors[:milestone], "must belong to the same project"
  end

  # Assignment follows membership. Assigning a non-member would render their
  # name on a project page they cannot open, and hand them work they cannot see.
  test "is invalid with an assignee who is not a member of the project" do
    story = Story.new(epic: epics(:launch), title: "Assigned to a stranger", assignee: users(:admin))

    assert_not story.valid?
    assert_includes story.errors[:assignee], "must be a member of this project"
  end

  test "is valid with an assignee who is a member of the project" do
    story = Story.new(epic: epics(:launch), title: "Assigned", assignee: users(:two))

    assert story.valid?
  end

  # New work arrives unsorted rather than ready to start, exactly as it does one
  # level up.
  test "is in the backlog when created without an explicit status" do
    story = Story.create!(epic: epics(:launch), title: "Fresh")
    assert story.backlog?
  end

  # One vocabulary across all three levels: a value outside it would leave the
  # backlog view with no column to put the row in.
  test "rejects a status outside the shared vocabulary" do
    story = Story.new(epic: epics(:launch), title: "Bad status", status: "shipped")

    assert_not story.valid?
    assert_includes story.errors[:status], "is not included in the list"
  end

  # Status is set by hand at every level — §3 rules out rollup — so a transition
  # simply persists what the user chose.
  test "status moves through the vocabulary and persists" do
    story = stories(:countdown)
    story.in_progress!

    assert story.reload.in_progress?
    assert_includes Story.in_progress, story
  end

  # Position is what the backlog tree orders by, so it is assigned on create:
  # a null would sort unpredictably against integers.
  test "appends new stories to the end of their epic's order" do
    story = Story.create!(epic: epics(:launch), title: "Latest")

    assert_equal epics(:launch).stories.maximum(:position), story.position
    assert_operator story.position, :>, stories(:countdown).position
  end

  # Ordering is per epic, not per project: the first story of one epic must not
  # be pushed down the list by unrelated stories under another.
  test "numbers positions independently in each epic" do
    story = Story.create!(epic: Epic.create!(project: projects(:apollo), title: "Recovery"), title: "First here")

    assert_equal 1, story.position
    assert_operator stories(:abort_switch).position, :>, story.position
  end

  test "ordered returns stories by position" do
    assert_equal [ stories(:countdown), stories(:abort_switch) ], epics(:launch).stories.ordered.to_a
  end

  # A story cannot outlive its epic: orphan rows would accumulate that no screen
  # can reach, and no membership scope guards.
  test "destroying an epic destroys its stories" do
    assert_difference -> { Story.count }, -1 do
      epics(:telemetry).destroy
    end
  end

  # Nullify, not destroy: dropping a ship date must not delete the work planned
  # against it. The story survives, unscheduled.
  test "destroying a milestone leaves its stories unscheduled" do
    story = stories(:countdown)
    assert_equal milestones(:v1), story.milestone

    milestones(:v1).destroy

    assert_nil story.reload.milestone_id
  end
end
