# Seed data for development, per §13 phase 7.
#
# Sign-up is disabled by design (§4), so a fresh clone is an app you cannot sign
# in to until this runs. That is what this file is for: one command between
# `bin/setup` and a working screen.
#
# Idempotent throughout — db:prepare runs it on every setup, and a second run
# must not duplicate anyone or trip the uniqueness rules on email and slug.
module Seeds
  # Shared by every seeded account, printed at the end, and committed to a
  # public repo. That is exactly why this file will not run in production.
  PASSWORD = "development-password" unless const_defined?(:PASSWORD, false)

  # Generic placeholders, per §13. example.com is reserved by RFC 2606 for
  # precisely this, so none of these can collide with a real address.
  PEOPLE = {
    "admin@example.com"   => "Sam Admin",
    "dana@example.com"    => "Dana Reyes",
    "kim@example.com"     => "Kim Osei",
    "alex@example.com"    => "Alex Marchetti",
    "robin@example.com"   => "Robin Silva"
  }.freeze

  class << self
    def call
      refuse_in_production!

      people = PEOPLE.map { |email, name| find_or_create_person(email, name) }.to_h { |u| [ u.email_address, u ] }
      people["admin@example.com"].update!(system_admin: true)

      build_launch_project(people)
      build_second_project(people)

      report(people)
    end

    private
      # These accounts share one password that is published in this repository.
      # On a real server that is a set of known credentials for every role
      # including system admin, so the file refuses rather than trusting whoever
      # typed the command.
      def refuse_in_production!
        return unless Rails.env.production?

        raise "db/seeds.rb refuses to run in production: every account it creates " \
              "shares a password that is committed to this repository. Create the " \
              "first real account from the console instead — see the README."
      end

      def find_or_create_person(email, name)
        User.find_or_create_by!(email_address: email) do |user|
          user.name = name
          user.password = PASSWORD
        end
      end

      # A backlog with enough in it to be worth opening: three levels, a mix of
      # statuses so the tree is not a column of identical rows, and progress
      # part-way along so the bars show something.
      def build_launch_project(people)
        project = find_or_create_project("apollo", "Apollo", "Getting the first release off the ground.")

        # Every role in §4's matrix, so the seeded app demonstrates the
        # permission system and not only the tree.
        grant(project, people["admin@example.com"], :owner)
        grant(project, people["dana@example.com"],  :admin)
        grant(project, people["kim@example.com"],   :member)
        grant(project, people["alex@example.com"],  :viewer)

        v1 = find_or_create_milestone(project, "v1.0", 3.weeks.from_now, "The first release.")
        find_or_create_milestone(project, "v1.1", 9.weeks.from_now, "Everything that slipped.")

        launch = find_or_create_epic(project, "Launch sequence", :in_progress,
                                     "Everything needed to get the release out.", v1)
        countdown = find_or_create_story(launch, "Countdown checklist", :done,
                                         "The steps to run on release day.", people["kim@example.com"])
        find_or_create_task(countdown, "Draft the checklist", :done)
        find_or_create_task(countdown, "Walk through it once", :done)

        rollback = find_or_create_story(launch, "Rollback plan", :in_progress,
                                        "How to get back if the release goes wrong.", people["dana@example.com"])
        find_or_create_task(rollback, "Write the restore steps", :done)
        find_or_create_task(rollback, "Test a restore", :in_progress)
        find_or_create_task(rollback, "Time how long it takes", :todo)

        find_or_create_story(launch, "Announcement", :backlog, "Tell people it shipped.", nil)

        telemetry = find_or_create_epic(project, "Telemetry", :todo,
                                        "Know what the app is doing once it is out.", nil)
        find_or_create_story(telemetry, "Error reporting", :backlog, "Somewhere errors go.", nil)
        find_or_create_story(telemetry, "Uptime checks", :blocked, "Waiting on a host.", nil)
      end

      # A second project so the app shows what it looks like to hold different
      # roles in different places — the §4 rule that a role in one project
      # grants nothing in another.
      def build_second_project(people)
        project = find_or_create_project("gemini", "Gemini", "The follow-up, still being scoped.")

        grant(project, people["dana@example.com"], :owner)
        grant(project, people["admin@example.com"], :member)
        grant(project, people["robin@example.com"], :member)

        scoping = find_or_create_epic(project, "Scoping", :in_progress, "Work out what this is.", nil)
        find_or_create_story(scoping, "Interview three users", :in_progress, nil, people["robin@example.com"])
      end

      def find_or_create_project(slug, name, description)
        Project.find_or_create_by!(slug: slug) do |project|
          project.name = name
          project.description = description
        end
      end

      # Roles are not re-applied on a second run: someone may have changed a
      # role in the app to try the permission system out, and re-seeding should
      # not quietly undo that.
      def grant(project, user, role)
        Membership.find_or_create_by!(project: project, user: user) { |m| m.role = role }
      end

      def find_or_create_milestone(project, title, due_on, description)
        project.milestones.find_or_create_by!(title: title) do |milestone|
          milestone.due_on = due_on
          milestone.description = description
        end
      end

      def find_or_create_epic(project, title, status, description, milestone)
        project.epics.find_or_create_by!(title: title) do |epic|
          epic.status = status
          epic.description = description
          epic.milestone = milestone
        end
      end

      def find_or_create_story(epic, title, status, description, assignee)
        epic.stories.find_or_create_by!(title: title) do |story|
          story.status = status
          story.description = description
          story.assignee = assignee
        end
      end

      def find_or_create_task(story, title, status)
        story.tasks.find_or_create_by!(title: title) { |task| task.status = status }
      end

      # Printed rather than left for the reader to find: the whole point is that
      # someone who has just cloned this can sign in on the next line.
      def report(people)
        return if Rails.env.test?

        # Counts the database, not what this run inserted — the file is
        # idempotent, so a second run inserts nothing and saying "seeded 0"
        # would be as misleading as claiming it made everything again.
        puts "\nYour database now holds #{User.count} people, #{Project.count} projects, " \
             "#{Epic.count} epics, #{Story.count} stories and #{Task.count} tasks."
        puts "Sign in at http://localhost:3000 as any of:"
        people.each_key { |email| puts "  #{email}" }
        puts "Password for all of them: #{PASSWORD}"
        puts "admin@example.com is the system admin — it is the one that can create projects.\n\n"
      end
  end
end

Seeds.call
