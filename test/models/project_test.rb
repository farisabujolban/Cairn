require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  # A nameless project is unidentifiable in the project list, which is the only
  # way into everything it contains.
  test "is invalid without a name" do
    project = Project.new(name: "")
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  # The slug is what appears in every nested URL, so it is derived rather than
  # typed. Punctuation and spacing in a name must not leak into the path.
  test "derives a url-safe slug from the name when none is given" do
    project = Project.create!(name: "  Apollo Program: Phase 2!  ")
    assert_equal "apollo-program-phase-2", project.slug
  end

  # An explicitly supplied slug is honoured, because renaming a project must not
  # silently break links people have already bookmarked or pasted into chat.
  test "keeps an explicitly provided slug when the name changes" do
    project = Project.create!(name: "Original", slug: "keeper")
    project.update!(name: "Renamed Entirely")
    assert_equal "keeper", project.slug
  end

  # Two projects sharing a slug would make the URL ambiguous and one of them
  # unreachable. Distinct names can still collide once punctuation is stripped.
  test "is invalid with a slug already taken by another project" do
    Project.create!(name: "Duplicate Target", slug: "taken")
    duplicate = Project.new(name: "Other", slug: "taken")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  # Slugs go straight into paths, so anything that would need escaping — spaces,
  # uppercase, slashes — is rejected instead of silently mangled.
  test "is invalid with a slug containing characters that are unsafe in a url" do
    [ "Has Spaces", "UPPER", "slash/es", "trailing-" ].each do |bad_slug|
      project = Project.new(name: "Bad", slug: bad_slug)
      assert_not project.valid?, "expected #{bad_slug.inspect} to be rejected"
      assert_includes project.errors[:slug], "must be lowercase letters, numbers and hyphens"
    end
  end

  # The form has no slug field, so a derived slug's errors name something the
  # user cannot see or correct. They are re-pointed at the name they came from.
  test "reports a taken derived slug against the name" do
    Project.create!(name: "Apollo Redesign")
    duplicate = Project.new(name: "Apollo Redesign")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
    assert_empty duplicate.errors[:slug]
  end

  # A name of pure punctuation parameterizes to "", so the slug is blank while
  # the name is not. Reporting "can't be blank" there would name the wrong field.
  test "reports a name that cannot produce a slug against the name" do
    project = Project.new(name: "!!!")

    assert_not project.valid?
    assert_includes project.errors[:name], "must contain at least one letter or number"
    assert_empty project.errors[:slug]
  end

  # A blank name already reports itself; the blank derived slug that follows adds
  # a second message for one mistake.
  test "reports a blank name once rather than twice" do
    project = Project.new(name: "")

    assert_not project.valid?
    assert_equal [ "can't be blank" ], project.errors[:name]
    assert_empty project.errors[:slug]
  end

  # An explicitly supplied slug is a field the caller chose, so its errors stay
  # on slug rather than being blamed on the name.
  test "keeps errors on an explicitly supplied slug" do
    project = Project.new(name: "Fine Name", slug: "UPPER")

    assert_not project.valid?
    assert_includes project.errors[:slug], "must be lowercase letters, numbers and hyphens"
    assert_empty project.errors[:name]
  end

  # Records are addressed by id. The spec lists slug as a unique column without
  # making it the URL identifier, so to_param stays Rails' default — pinned here
  # because overriding it silently rewrites every path helper in the app.
  test "to_param returns the id, leaving slug as a plain unique attribute" do
    project = projects(:apollo)
    assert_equal project.id.to_s, project.to_param
  end

  # Archiving is a soft delete: the project keeps its rows but must drop out of
  # the default listing, otherwise archiving would change nothing a user sees.
  test "active scope excludes archived projects" do
    assert_includes Project.active, projects(:apollo)
    assert_not_includes Project.active, projects(:archived)
  end

  # archived? is what every view branches on, so it must be derived from the
  # timestamp rather than tracked as a second, drift-prone boolean column.
  test "archived? reflects the presence of archived_at" do
    assert projects(:archived).archived?
    assert_not projects(:apollo).archived?
  end

  # Archiving has to be reversible from the model up: the project list filters
  # to active, so a project with no way back is one the only screen that could
  # restore it has already hidden.
  test "archive! and restore! move a project in and out of the active listing" do
    project = projects(:apollo)

    project.archive!
    assert project.archived?
    assert_not_includes Project.active, project

    project.restore!
    assert_not project.archived?
    assert_includes Project.active, project
  end

  # "Archived 3 days ago" is the only thing the archived listing says about a
  # project. Re-stamping the timestamp on a second archive! would make that
  # sentence lie every time someone pressed the button twice.
  test "archive! leaves an already archived project's timestamp alone" do
    project = projects(:archived)
    archived_at = project.archived_at

    project.archive!

    assert_equal archived_at, project.reload.archived_at
  end

  # Archiving is a soft delete, not a revocation: the rows stay, the memberships
  # stay, and anyone who could open the project before still can. Only the
  # default listing changes.
  test "archiving does not change who can see the project" do
    project = projects(:apollo)
    project.archive!

    assert_includes Project.visible_to(users(:one)), project
  end

  # The backlog tree and the delete confirmation both ask the project for work
  # two and three levels down. Reaching it through the epics keeps containment
  # the single answer to "which project is this in" — a story_id column on
  # projects would be a second answer that could disagree with the first.
  test "reaches its stories and tasks through the epics" do
    project = projects(:apollo)

    assert_includes project.stories, stories(:countdown)
    assert_includes project.tasks, tasks(:wire_the_clock)
    assert_not_includes project.stories, stories(:gemini_docking)
    assert_not_includes project.tasks, tasks(:gemini_latch)
  end

  # A bare "are you sure?" hides the size of the cascade behind the button. The
  # confirmation has to name what goes with the project, so the counts come from
  # the project rather than from whatever the person happens to have open.
  test "contents counts everything a delete would take with the project" do
    assert_equal({ "epic" => 2, "story" => 3, "task" => 2, "milestone" => 3, "member" => 4 },
                 projects(:apollo).contents)
  end

  # "0 tasks" is noise in a sentence someone is reading to decide whether to
  # stop. An empty project has nothing to warn about, and says so by being empty.
  test "contents omits the levels that are empty" do
    project = Project.create!(name: "Empty")

    assert_equal({}, project.contents)
  end

  # Memberships are meaningless without their project — an orphaned grant would
  # point at a project id that no longer resolves, which authorization code
  # would have to defend against forever.
  test "destroying a project destroys its memberships" do
    project = projects(:apollo)

    # Counted from the project rather than hardcoded: Apollo gains members as
    # the role fixtures grow, and the claim is "all of its own and none of
    # anyone else's", not "two".
    assert_difference -> { Membership.count }, -project.memberships.count do
      project.destroy
    end
  end

  # A milestone is scoped to its project and has no meaning outside it. Left
  # behind, it would be a dated bucket nobody can reach, still holding a
  # project_id that no longer resolves.
  test "destroying a project destroys its milestones" do
    assert_difference -> { Milestone.count }, -3 do
      projects(:apollo).destroy
    end
  end

  # Epics are the top of the containment tree and belong to exactly one project.
  # Orphaned, they would be unreachable from every screen while still matching
  # searches and counts.
  test "destroying a project destroys its epics" do
    assert_difference -> { Epic.count }, -2 do
      projects(:apollo).destroy
    end
  end

  # Ownership transfer is the only sanctioned way past the one-owner rule: both
  # halves must happen together, or the project ends with two owners or none.
  test "transfer_ownership_to! promotes the new owner and demotes the old one" do
    project = projects(:apollo)
    project.transfer_ownership_to!(users(:two))

    assert_equal "owner", project.memberships.find_by(user: users(:two)).role
    assert_equal "admin", project.memberships.find_by(user: users(:one)).role
    assert_equal 1, project.memberships.owner.count
  end

  # Transferring to someone outside the project would grant access as a side
  # effect of a role change. Adding a member is a separate, audited action.
  test "transfer_ownership_to! refuses a user who is not a member" do
    assert_raises ActiveRecord::RecordNotFound do
      projects(:apollo).transfer_ownership_to!(users(:admin))
    end
  end

  # If the promotion half fails, the demotion half must not survive it, or the
  # project is left with no owner at all.
  test "transfer_ownership_to! leaves the existing owner in place when it fails" do
    project = projects(:apollo)

    assert_raises ActiveRecord::RecordNotFound do
      project.transfer_ownership_to!(users(:admin))
    end

    assert_equal "owner", project.memberships.reload.find_by(user: users(:one)).role
  end

  # The core multi-tenant rule: a project a user has no membership in must never
  # appear in a list. Membership, not existence, is what makes a project visible.
  test "visible_to returns only projects the user is a member of" do
    visible = Project.visible_to(users(:one))

    assert_includes visible, projects(:apollo)
    assert_includes visible, projects(:gemini)
    assert_not_includes visible, projects(:archived)
  end

  # system_admin is a bootstrap privilege for creating users and projects, not a
  # backdoor into every team's content. It grants no membership by itself.
  test "visible_to grants a system admin nothing without a membership" do
    assert_empty Project.visible_to(users(:admin))
  end
end
