require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # §13 phase 5 asks for a confirmation that says what is about to be destroyed
  # rather than a bare "are you sure?". The cascade reaches four levels, and the
  # person deciding is looking at one screen of it at most.
  test "deletion_warning names every level the cascade reaches" do
    warning = deletion_warning(projects(:apollo))

    assert_includes warning, "2 epics"
    assert_includes warning, "3 stories"
    assert_includes warning, "2 tasks"
    assert_includes warning, "3 milestones"
    assert_includes warning, "4 members"
    assert_includes warning, "cannot be undone"
  end

  # The project's own name, not "this project": the confirmation is the last
  # thing standing between a wrong click and an irreversible cascade, so it has
  # to be checkable against what the person meant to delete.
  test "deletion_warning names the project being deleted" do
    assert_includes deletion_warning(projects(:apollo)), "Apollo"
  end

  # Pluralization is per level, not for the sentence as a whole — a project with
  # one epic and four stories must not read "1 epics".
  test "deletion_warning pluralizes each level on its own count" do
    project = Project.create!(name: "Single")
    epic = project.epics.create!(title: "Only epic")
    2.times { |n| epic.stories.create!(title: "Story #{n}") }

    assert_includes deletion_warning(project), "1 epic and 2 stories"
  end

  # An empty project has nothing to warn about, and a sentence listing nothing
  # would read as a bug. It still says the delete is final.
  test "deletion_warning drops the inventory when there is nothing to destroy" do
    warning = deletion_warning(Project.create!(name: "Empty"))

    assert_includes warning, "cannot be undone"
    assert_not_includes warning, "destroys"
  end
  # String#pluralize(1) returns its receiver untouched, assuming a singular one,
  # and every caller names its unit in the plural. Without the singularize step
  # the sentence reads "0 of 1 stories done" on the app's busiest screen.
  test "progress_sentence agrees a plural unit with a count of one" do
    assert_equal "0 of 1 story done", progress_sentence(Progress.new(done: 0, total: 1), "stories")
    assert_equal "1 of 2 tasks done", progress_sentence(Progress.new(done: 1, total: 2), "tasks")
  end

  # The tree names its units in title case for the button label beside them, so
  # the sentence lowercases rather than each caller remembering to.
  test "progress_sentence lowercases the unit it is given" do
    assert_equal "0 of 3 stories done", progress_sentence(Progress.new(done: 0, total: 3), "Stories")
  end
end
