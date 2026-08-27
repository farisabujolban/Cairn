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

  # URLs are built from the slug, so to_param must not fall back to the id —
  # otherwise half the links in the app would be numeric and half readable.
  test "to_param returns the slug rather than the id" do
    assert_equal "apollo", projects(:apollo).to_param
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

  # Memberships are meaningless without their project — an orphaned grant would
  # point at a project id that no longer resolves, which authorization code
  # would have to defend against forever.
  test "destroying a project destroys its memberships" do
    assert_difference -> { Membership.count }, -2 do
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
