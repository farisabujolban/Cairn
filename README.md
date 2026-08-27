# Project Tracker

A lightweight issue tracker for a single team. Projects contain epics, epics contain user
stories, stories contain tasks. Milestones group work by ship date.

`SPEC.md` is the source of truth for every decision in this codebase.

## Versions, as installed

Recorded rather than pinned by the spec — these are what `rails new` actually produced here:

| | |
|---|---|
| Ruby | 4.0.5 |
| Rails | 8.1.3.1 |
| Database | SQLite 3.51.0 (all environments) |
| Frontend | Hotwire (Turbo + Stimulus) over import maps — no Node build step |
| CSS | Tailwind via `tailwindcss-rails` |
| Tests | Minitest + fixtures, Capybara for system tests |

## Local development

Development runs natively. There is no `docker-compose.yml` and no dev container: SQLite is a
file, and Solid Queue / Solid Cache / Solid Cable all run on that same database, so there are no
companion services to orchestrate.

```sh
bin/setup          # installs gems, prepares the database
bin/dev            # starts Puma and the Tailwind watcher
```

If `rails` on your `PATH` resolves to Apple's stub at `/usr/bin/rails`, add the gem bindir
(`ruby -e 'puts Gem.bindir'`) ahead of `/usr/bin` in your shell profile. Inside the project,
`bin/rails` is what matters and already resolves correctly.

## Tests

```sh
bin/rails test         # models, controllers, integration
bin/rails test:system  # Capybara + headless Chrome
bin/ci                 # everything CI runs, in one pass
```

Every check in `.github/workflows/ci.yml` is blocking, including Brakeman, `bundler-audit`,
`importmap audit`, and `script/check_test_coverage.rb` — which fails the build when a model,
controller, policy or helper has no test file.

## Creating the first user

Open sign-up is disabled by design. The first account is created from the console; after that a
project owner or admin adds existing users to a project by email address.

```sh
bin/rails console
```

```ruby
User.create!(
  name: "Your Name",
  email_address: "you@example.com",
  password: "a-long-password",
  system_admin: true
)
```

`system_admin` is a bootstrap privilege, not a superuser: it allows creating users and projects
and grants no access to any project the user is not a member of. Project permissions come from
`Membership#role` (`owner` / `admin` / `member` / `viewer`) — see `SPEC.md` §4 for the matrix.

## Deployment

Kamal to a single VPS, with Thruster in front of Puma inside the container. Not yet configured —
see `SPEC.md` §12. **The SQLite database lives in `storage/`, which must be a persistent volume:
a container redeploy without one silently destroys every project, epic, story and task.**
