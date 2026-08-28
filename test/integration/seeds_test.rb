require "test_helper"

# db/seeds.rb is the only way into a fresh clone: sign-up is disabled by design
# (§4), so without seeds the app you just set up is one you cannot sign in to.
# CI runs db:seed:replant, which proves they load — these prove they are worth
# loading.
class SeedsTest < ActiveSupport::TestCase
  # Fixtures and seeds both write to the same tables, and seeds look records up
  # by email and slug. Starting empty is what makes "running twice changes
  # nothing" mean anything.
  setup do
    [ Task, Story, Epic, Milestone, Membership, Project, Session, User ].each(&:delete_all)
  end

  # The point of the whole file. A fresh clone must yield an account that can
  # sign in and create the first project.
  test "seeding produces a system admin who can sign in" do
    load_seeds

    admin = User.find_by(system_admin: true)

    assert admin.present?, "no system admin was seeded, so nobody can create anything"
    assert admin.authenticate(Seeds::PASSWORD), "the seeded password does not work"
  end

  # §13 asks for generic placeholder users. Seeds land in a repo that is public,
  # so a real name or address in them is published with it.
  test "seeded users are placeholders, not real people" do
    load_seeds

    User.find_each do |user|
      assert_match(/@example\.com\z/, user.email_address,
                   "#{user.email_address} is not a reserved example address")
    end
  end

  # Idempotent per the file's own instruction — it is run again on every
  # db:prepare, and a second run must not duplicate anyone or raise on the
  # uniqueness rules for email and slug.
  test "seeding twice changes nothing" do
    load_seeds
    counts = -> { [ User.count, Project.count, Membership.count, Epic.count, Story.count, Task.count ] }
    after_first = counts.call

    load_seeds

    assert_equal after_first, counts.call
  end

  # A seeded project with no epics would show an empty backlog, which teaches a
  # newcomer nothing about what the app is for. The tree needs all three levels
  # to be worth opening.
  test "seeding fills a project to every level of the tree" do
    load_seeds
    project = Project.first

    assert_operator project.epics.count, :>, 0
    assert_operator project.stories.count, :>, 0
    assert_operator project.tasks.count, :>, 0
    assert_operator project.memberships.count, :>, 1, "a team of one demonstrates no roles"
  end

  # Every role in §4's matrix, so the seeded app can actually show what the
  # permission system does rather than only what the tree looks like.
  test "seeding covers every membership role" do
    load_seeds

    assert_equal Membership::ROLES.sort, Membership.distinct.pluck(:role).sort
  end

  # These accounts share one published password. In development that is the
  # point; on a production server it is a set of known credentials, so the file
  # refuses rather than trusting whoever typed the command.
  test "seeding refuses to run in production" do
    original = Rails.env
    Rails.env = "production"

    error = assert_raises(RuntimeError) { load_seeds }

    assert_match(/production/i, error.message)
    assert_equal 0, User.count, "it raised but had already written rows"
  ensure
    Rails.env = original
  end

  private
    def load_seeds = load Rails.root.join("db/seeds.rb")
end
