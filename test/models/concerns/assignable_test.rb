require "test_helper"

class AssignableTest < ActiveSupport::TestCase
  MODELS = [ Story, Task ].freeze

  # Assignment exists at exactly the two levels people pick work up at. An epic
  # is a container, not something one person holds.
  test "stories and tasks are assignable and epics are not" do
    MODELS.each do |model|
      assert model.include?(Assignable), "#{model} is not assignable"
    end

    assert_not Epic.include?(Assignable)
    assert_not Epic.new.respond_to?(:assignee)
  end

  # Writing work down and picking it up are separate steps, so unassigned is a
  # valid resting state at both levels.
  test "both levels are valid unassigned" do
    each_record do |record|
      record.assignee = nil

      assert record.valid?, "#{record.class} rejected being unassigned"
    end
  end

  test "both levels accept an assignee who is a member of the project" do
    each_record do |record|
      record.assignee = users(:two)

      assert record.valid?, "#{record.class} rejected a member as assignee"
    end
  end

  # The guard, in one place instead of two: assigning a non-member would print
  # their name on a project page they cannot open, and hand them work they
  # cannot see. The admin fixture is deliberately a member of no project.
  test "both levels reject an assignee who is not a member of the project" do
    each_record do |record|
      record.assignee = users(:admin)

      assert_not record.valid?, "#{record.class} accepted a non-member as assignee"
      assert_includes record.errors[:assignee], "must be a member of this project"
    end
  end

  # Removing someone from the app must not delete the work they were holding.
  # It goes back to unassigned, where anyone can pick it up. A fresh member is
  # created rather than reusing a fixture because both fixture members own a
  # project, and a sole owner is refused deletion by design.
  test "destroying a user unassigns their work rather than deleting it" do
    helper = User.create!(name: "Temp Helper", email_address: "helper@example.com", password: "password")
    projects(:apollo).memberships.create!(user: helper, role: :member)
    story = stories(:countdown)
    task = tasks(:wire_the_clock)
    story.update!(assignee: helper)
    task.update!(assignee: helper)

    assert_no_difference -> { Story.count + Task.count } do
      assert helper.destroy
    end

    assert_nil story.reload.assignee_id
    assert_nil task.reload.assignee_id
  end

  private
    def each_record
      [ Story.new(epic: epics(:launch), title: "Assignable"),
        Task.new(story: stories(:countdown), title: "Assignable") ].each { |record| yield record }
    end
end
