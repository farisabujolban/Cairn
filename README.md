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
| **Owner** | Everything, including deleting the project and handing it to someone else. One per project. |
| **Admin** | Everything except those two. Can add and remove people, and archive the project. |
| **Member** | Create and change epics, stories, tasks and milestones. Cannot manage people. |
| **Viewer** | Read everything. Change nothing. |

Somebody who is not a member of a project cannot see it at all — it does not
appear in their list, and opening its address directly tells them nothing.

## Running it on your own machine

You need Ruby and a terminal. There is no Docker, no database server to install,
and nothing else to start alongside it — the database is a single file.

```sh
bin/setup         # installs everything and prepares the database
bin/rails db:seed # fills it with example data you can sign in to
bin/dev           # starts the app
```

Then open **http://localhost:3000** in a browser.

To stop it, press `Ctrl+C` in the terminal.

## Looking around

`bin/rails db:seed` creates a handful of example people and two projects with a
real backlog in them, then prints the addresses it made. Sign in as any of them
with the password **`development-password`**:

| Address | What they are |
|---|---|
| `admin@example.com` | System admin — the only one who can create projects |
| `dana@example.com` | Owner of one project, admin of the other |
| `kim@example.com` | An ordinary member |
| `alex@example.com` | A viewer — reads everything, changes nothing |

Signing in as each of them is the quickest way to see what the roles actually
do. Running the command again is safe: it tops up what is missing and changes
nothing that is already there.

These accounts are for looking around on your own machine. They all share one
password that is published in this file, so the seed command **refuses to run on
a real server** — see below for how to start one of those.

## Starting a real one

There is no public sign-up page, on purpose: this is a tool for one team, not a
service strangers join. So the first real account is made from the terminal.

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

Once the account exists, putting that person on a project is done in the app.
Open the project, click **Members**, then **Add member**, and choose the person
and the role you want them to have. The same screen changes somebody's role
later, or removes them from the project.

Everyone on a project can see the member list — knowing who to ask about a piece
of work is ordinary use. Only owners and admins can change it.

## Working through the backlog

Opening a project shows its backlog: every epic, with its stories underneath,
and each story's tasks under those. It is the one screen that shows the whole
shape of a project at once, and the one you would leave open all day.

Epics open with their stories showing. Tasks stay folded until you ask for them
— use the arrow beside a story. The arrow beside an epic folds the whole thing
away while you work on something else.

Every row's status can be changed on the spot, without opening the item first.
Pick a new one and it saves straight away. Nothing else on the page moves, so
anything you had unfolded stays unfolded.

The five statuses are **Backlog**, **Todo**, **In progress**, **Blocked** and
**Done**, and they mean whatever your team decides. None of it is automatic: a
story does not become done when its last task does. Somebody says so.

The progress under an epic or a story counts what is done beneath it, so you can
see how far along something is without unfolding it.

## Using it from the keyboard

Everything works without a mouse. Pressing Tab on any page offers **Skip to main
content** first, which jumps past the navigation to the page itself. Whatever
has the keyboard's attention is always outlined, and every button and menu says
what it is to a screen reader.

If your computer is set to reduce motion, the app stops animating.

## Handing a project to someone else

A project has exactly one owner, and only the owner can pass it on. On the
**Members** screen, set the person's role to **Owner**. They become the owner
and you become an admin, in one step — the project is never left with two owners
or none.

This is the only way the owner changes. An owner cannot simply demote
themselves, because that would leave a project nobody can transfer or delete,
and an admin cannot demote the owner to take it from them.

## Putting a project away

A finished project does not have to sit in your list forever. **Archive** it
from the project page and it moves out of the way. The **Archived** tab above
the project list is where it goes, and **Restore** brings it straight back —
nothing is lost, and the epics, stories, tasks and people are exactly as you
left them.

Owners and admins can archive, and the reason they can is that it is always
reversible.

**Delete** is not reversible, and only the owner has it. Deleting a project
destroys everything inside it: every epic, story, task and milestone, and the
record of who was on it. The confirmation counts all of that up before you
agree to it, so you can see the size of what you are about to lose. If you only
want the project out of your way, archive it instead.

## Versions, as installed

| | |
|---|---|
| Ruby | 4.0.5 |
| Rails | 8.1.3.1 |
| Database | SQLite 3.51.0 (all environments) |
| Frontend | Hotwire (Turbo + Stimulus) over import maps — no Node build step |
| CSS | Tailwind via `tailwindcss-rails` |
| Authorization | Pundit — one policy class per model |
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

## License

MIT — see [LICENSE](LICENSE). You may use, change and redistribute this code,
including commercially, as long as the copyright notice stays with it.
