require "test_helper"

class WorkItemStatusTest < ActiveSupport::TestCase
  MODELS = [ Epic, Story, Task ].freeze

  # One vocabulary, defined once. Three copies of the same array would drift the
  # first time a status is added, and the backlog view would then have rows it
  # cannot place in any column.
  test "every work-item level shares one status vocabulary" do
    MODELS.each do |model|
      assert_equal WorkItemStatus::STATUSES, model::STATUSES, "#{model} does not share the vocabulary"
      assert_equal WorkItemStatus::STATUSES, model.statuses.keys
    end
  end

  # The order is meaningful — unsorted through to finished — and the views print
  # the select options straight from it.
  test "the vocabulary runs from unsorted to finished" do
    assert_equal %w[ backlog todo in_progress blocked done ], WorkItemStatus::STATUSES
  end

  # Each level answers the same questions, so a partial can ask any row whether
  # it is done without caring which level it came from.
  test "every level gets the same predicates, bang methods and scopes" do
    MODELS.each do |model|
      WorkItemStatus::STATUSES.each do |status|
        assert model.new.respond_to?("#{status}?"), "#{model} has no ##{status}?"
        assert model.new.respond_to?("#{status}!"), "#{model} has no ##{status}!"
        assert model.respond_to?(status), "#{model} has no .#{status} scope"
      end
    end
  end

  # A status outside the vocabulary is rejected at every level, not just the one
  # whose test happened to cover it.
  test "every level rejects a status outside the vocabulary" do
    records = [
      Epic.new(project: projects(:apollo), title: "Bad"),
      Story.new(epic: epics(:launch), title: "Bad"),
      Task.new(story: stories(:countdown), title: "Bad")
    ]

    records.each do |record|
      record.status = "shipped"

      assert_not record.valid?, "#{record.class} accepted a status outside the vocabulary"
      assert_includes record.errors[:status], "is not included in the list"
    end
  end

  # Blank is not a status either: a null would leave the row uncolumned exactly
  # as an unknown value would.
  test "every level requires a status" do
    records = [
      Epic.new(project: projects(:apollo), title: "Blank", status: nil),
      Story.new(epic: epics(:launch), title: "Blank", status: nil),
      Task.new(story: stories(:countdown), title: "Blank", status: nil)
    ]

    records.each do |record|
      assert_not record.valid?, "#{record.class} accepted a blank status"
      assert_includes record.errors[:status], "can't be blank"
    end
  end
end
