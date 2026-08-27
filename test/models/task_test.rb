require "test_helper"

class TaskTest < ActiveSupport::TestCase
  # A task is a checklist line on a story; an untitled one says nothing.
  test "is invalid without a title" do
    task = Task.new(story: stories(:countdown), title: "")
    assert_not task.valid?
    assert_includes task.errors[:title], "can't be blank"
  end

  # Guards the no-subtasks rule at the model level: every task hangs off a
  # story, so there is no such thing as a free-floating one to nest under.
  test "is invalid without a story" do
    task = Task.new(title: "Orphan")
    assert_not task.valid?
    assert_includes task.errors[:story], "must exist"
  end

  # §6, enforced by the database rather than by discipline. Skipping validations
  # is exactly what a future "flexible" code path would do, and NOT NULL is what
  # makes it fail loudly instead of quietly creating a rootless task.
  test "the database refuses a task with no story" do
    assert_raises ActiveRecord::NotNullViolation do
      Task.new(title: "Rootless").save(validate: false)
    end
  end

  # §6 again, from the other side: nesting is impossible because there is
  # nowhere to record a parent. This fails the moment a migration adds one.
  test "the tasks table has no parent column" do
    assert_empty Task.column_names.grep(/parent/)
    assert_not Task.reflect_on_all_associations.any? { |a| a.class_name == "Task" }
  end

  # A task is a leaf: the tree stops here, so it carries no children of its own.
  test "has no children association" do
    assert_not Task.new.respond_to?(:tasks)
    assert_not Task.new.respond_to?(:subtasks)
  end

  # The project is reached through the story's epic, so a task inherits exactly
  # one project and cannot be pointed at another.
  test "belongs to its story's project" do
    assert_equal projects(:apollo), tasks(:wire_the_clock).project
  end

  # Picking work up is a separate step from writing it down, so a task starts
  # unassigned.
  test "is valid without an assignee" do
    task = Task.new(story: stories(:countdown), title: "Unclaimed")

    assert task.valid?
    assert_nil task.assignee
  end

  # Assignment follows membership: handing work to a non-member would print
  # their name on a project page they cannot open.
  test "is invalid with an assignee who is not a member of the project" do
    task = Task.new(story: stories(:countdown), title: "Assigned to a stranger", assignee: users(:admin))

    assert_not task.valid?
    assert_includes task.errors[:assignee], "must be a member of this project"
  end

  test "is in the backlog when created without an explicit status" do
    task = Task.create!(story: stories(:countdown), title: "Fresh")
    assert task.backlog?
  end

  # The same vocabulary as Story and Epic — one set of columns for the backlog
  # view, whatever level a row came from.
  test "rejects a status outside the shared vocabulary" do
    task = Task.new(story: stories(:countdown), title: "Bad status", status: "shipped")

    assert_not task.valid?
    assert_includes task.errors[:status], "is not included in the list"
  end

  # A finished task does not finish its story: §3 rules out rollup, so the
  # story's own status must be untouched by this.
  test "completing a task leaves its story's status alone" do
    task = tasks(:wire_the_clock)

    task.done!

    assert task.reload.done?
    assert stories(:countdown).reload.backlog?
  end

  test "appends new tasks to the end of their story's order" do
    task = Task.create!(story: stories(:countdown), title: "Latest")

    assert_equal stories(:countdown).tasks.maximum(:position), task.position
    assert_operator task.position, :>, tasks(:wire_the_clock).position
  end

  # Ordering is per story: another story's checklist must not push this one's
  # first task down the list.
  test "numbers positions independently in each story" do
    task = Task.create!(story: stories(:abort_switch), title: "First here")

    assert_equal 1, task.position
    assert_operator tasks(:hold_at_t_minus).position, :>, task.position
  end

  test "ordered returns tasks by position" do
    assert_equal [ tasks(:wire_the_clock), tasks(:hold_at_t_minus) ], stories(:countdown).tasks.ordered.to_a
  end

  # A Task cannot outlive its Story: deleting the parent must cascade, otherwise
  # orphan rows accumulate that no screen can reach or clean up.
  test "destroying a story destroys its tasks" do
    assert_difference -> { Task.count }, -2 do
      stories(:countdown).destroy
    end
  end

  # The cascade runs the whole height of the tree: deleting an epic takes its
  # stories, and their tasks go with them.
  test "destroying an epic destroys the tasks under its stories" do
    assert_difference -> { Task.count }, -2 do
      epics(:launch).destroy
    end
  end
end
