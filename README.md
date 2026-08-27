# Project Tracker

A lightweight issue tracker for a single team.

Work is organised in three levels, and only three. A **project** holds **epics**
— large pieces of work. Each epic holds **stories**, which describe something a
person actually wants. Each story holds **tasks**, the individual steps. Tasks
are the bottom: they never contain anything else.

Separately from that, **milestones** group work by ship date, so "what is going
out in v1.2?" is a question the tool can answer directly.

It is deliberately not a Jira clone. The goal is the smallest tool that tracks
real work.

## Who can do what

Everyone signs in, and permissions are set per project. A person can be an owner
of one project and a viewer of another.

| Role | Can do |
|---|---|
| **Owner** | Everything, including deleting the project and handing ownership to someone else. One per project. |
| **Admin** | Everything except deleting the project or transferring ownership. Can add and remove people. |
| **Member** | Create and change epics, stories, tasks and milestones. Cannot manage people. |
| **Viewer** | Read everything. Change nothing. |

Somebody who is not a member of a project cannot see it at all — it does not
appear in their list, and opening its address directly tells them nothing.

## Running it on your own machine

You need Ruby and a terminal. There is no Docker, no database server to install,
and nothing else to start alongside it — the database is a single file.

```sh
bin/setup    # installs everything and prepares the database
bin/dev      # starts the app
```

Then open **http://localhost:3000** in a browser.

To stop it, press `Ctrl+C` in the terminal.

## Creating the first user

There is no public sign-up page, on purpose: this is a tool for one team, not a
service strangers join. That means the very first account has to be made from
the terminal.

**1.** With the app set up, start the Rails console:

```sh
bin/rails console
```

**2.** Paste this in, changing the name, email and password to your own. Use a
long password — this account can create every other account.

```ruby
User.create!(
  name: "Your Name",
  email_address: "you@example.com",
  password: "a-long-password-you-choose",
  system_admin: true
)
```

**3.** Type `exit` to leave the console, then sign in at
http://localhost:3000 with the email and password you just used.

`system_admin: true` is what lets this account create projects and other
accounts. It is not a master key: it grants no access to any project the account
is not a member of.

## Adding your teammates

Everyone needs an account before they can be added to anything, and accounts are
made the same way as the first one — from `bin/rails console`, without
`system_admin`:

```ruby
User.create!(
  name: "A Teammate",
  email_address: "them@example.com",
  password: "a-password-to-share-with-them"
)
```

Putting that person on a project is also done from the console. Pick the project
and the role you want them to have:

```ruby
Project.find_by!(name: "Apollo").memberships.create!(
  user: User.find_by!(email_address: "them@example.com"),
  role: :member    # or :admin, :viewer
)
```

## Versions, as installed

| | |
|---|---|
| Ruby | 4.0.5 |
| Rails | 8.1.3.1 |
| Database | SQLite 3.51.0 (all environments) |
| Frontend | Hotwire (Turbo + Stimulus) over import maps — no Node build step |
| CSS | Tailwind via `tailwindcss-rails` |
| Tests | Minitest + fixtures, Capybara for system tests |

## Tests

```sh
bin/rails test         # models, controllers, integration
bin/rails test:system  # browser tests
bin/ci                 # everything CI runs, in one pass
```

Every check in `.github/workflows/ci.yml` is blocking, including Brakeman,
`bundler-audit`, `importmap audit`, and `script/check_test_coverage.rb`, which
fails the build when a model, controller, policy or helper has no test file.

## For developers

`SPEC.md` is the source of truth for every decision in this codebase — stack,
domain model, authorization, security. Read it before changing anything.

If `rails` on your `PATH` resolves to Apple's stub at `/usr/bin/rails`, add the
gem bindir (`ruby -e 'puts Gem.bindir'`) ahead of `/usr/bin` in your shell
profile. Inside the project, `bin/rails` already resolves correctly.
