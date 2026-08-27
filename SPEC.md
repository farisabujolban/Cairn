# Project Tracker — Build Specification

This document is the source of truth for this project. Read it fully before writing any code, and
re-read it at the start of every phase.

Everything here is a decision that has already been made, with the reasoning attached. Where a
reason is given, it exists so you do not "improve" the decision into something worse. If you
believe a decision is wrong, **ask** — do not silently substitute an equivalent.

---

## 1. Product summary & delivery target

A lightweight issue tracker for a single team. Projects contain epics, epics contain user stories,
stories contain tasks. Milestones group work by ship date. This is deliberately **not** a Jira
clone — the goal is the smallest tool that tracks real work.

**What you are building:** a **server-rendered, multi-page web application** accessed in a browser
and **deployed to a server so a small team signs in over the internet**.

It is **not** a desktop app, not an Electron shell, not a JSON API with a separate frontend. Every
UI decision in this document follows from that.

### What "deployed for a team" changes

It is easy to build a single-user app by accident. It is not one:

- **Authorization is load-bearing, not decorative.** Every controller action scopes through the
  current user's memberships. A user who is not a member of a project must get a 404 and must
  never learn the project exists. This gets request tests, not just a `before_action`.
- **No `localhost` assumptions.** No hardcoded hosts. Build URLs with route helpers.
- **Secrets** live in Rails encrypted credentials or environment variables. Never committed.
- **SQLite in production needs a persistent volume and a backup story.** See §12.

---

## 2. Stack

### Environment, as actually measured

Do not assume; these were checked:

- Ruby **4.0.5** is present (`ruby -v`).
- Rails is **not installed** — `rails -v` reports "Rails is not currently installed on this
  system." **Phase 1 begins with `gem install rails`.**
- Node 22 is present but not needed. See import maps below.
- **No local Postgres** (`psql` not found).

### Version policy — do not hardcode

This spec deliberately **does not pin a Rails version**. Install the current stable Rails, run
`rails -v`, and record the actual version in the README. Everything below assumes **Rails 8 or
newer** and is written as a capability requirement rather than a version number.

### Decisions

- **SQLite** for all environments. Rails 8+ ships a production-viable SQLite setup, and there is
  no local Postgres. Use the Solid Queue / Solid Cache / Solid Cable defaults.

  This is a sound choice for a single-server deployment, but only **with a persistent volume and
  backups** (§12). Postgres is the designated swap point if the app ever outgrows one box, so
  **do not write raw SQL that would block that swap** — with one documented exception in §8.

- **Hotwire** (Turbo + Stimulus) via **import maps**. No Node build step.
- **Tailwind** via `tailwindcss-rails`.
- **Authentication: the built-in Rails generator** (`bin/rails generate authentication`).
  Not Devise. Not a hosted identity provider. Sessions stay in our own database.

  Verify the generator exists in the installed version via `bin/rails generate --help` before
  relying on it. If it has been renamed or removed, **ask** — do not substitute something else.
  If password-less sign-in is wanted later, the path is OmniAuth + Google OAuth.

- **Authorization: Pundit.** See §4.
- **Testing: Minitest + fixtures**, the Rails default. System tests with Capybara for main flows.
  Written test-first — see §9.
- No API-only mode. No GraphQL.

### Containerization — production yes, development no

This split is deliberate. Do not "helpfully" containerize development.

**Production is containerized.** `rails new` generates a `Dockerfile` and Kamal configuration.
Kamal builds an image, pushes it to a registry, and runs it on the VPS, with **Thruster** as the
HTTP proxy in front of Puma inside the container. Use the generated `Dockerfile` — it already
handles the multi-stage build and the native extensions that `sqlite3` and `bcrypt` need. See §12.

**Development runs natively.** `bin/dev` on the local machine, using the Ruby already installed.
**No `docker-compose.yml`, no dev container.**

The reason is specific rather than aesthetic: the usual justification for Compose in development
is orchestrating Postgres and Redis alongside the app. **This stack has neither.** SQLite is a
file, and Solid Queue / Solid Cache / Solid Cable all run on that same SQLite database — so there
are no companion services to orchestrate. A dev container here would add slow macOS file-watching
and extra moving parts in exchange for nothing.

---

## 3. Domain model

- **`User`** — from the auth generator, plus `name` and `system_admin` (boolean, default `false`).
- **`Project`** — `name`, `slug` (unique), `description`, `archived_at`.
- **`Membership`** — `user_id`, `project_id`, `role` enum (`owner` / `admin` / `member` /
  `viewer`), unique on the `[user_id, project_id]` pair. See §4.
- **`Milestone`** — `project_id`, `title`, `description`, `due_on`, `state` enum
  (`open` / `closed`).
- **`Epic`** — `project_id` (required), `milestone_id` (**optional**), `title`, `description`,
  `status`, `position`.
- **`Story`** — `epic_id` (**required**), `milestone_id` (optional), `assignee_id` (optional),
  `title`, `description`, `status`, `position`.
- **`Task`** — `story_id` (**required, `NOT NULL`**), `assignee_id` (optional), `title`, `status`,
  `position`.

**Shared `status` enum** across all three work-item levels, one vocabulary:
`backlog` · `todo` · `in_progress` · `blocked` · `done`.

**Associations:** `Project has_many :epics`, `Epic has_many :stories`, `Story has_many :tasks`,
each `dependent: :destroy`.

A `progress` helper on `Story` and `Epic` computes done-count / total-count for a progress bar.
**Status is set manually — there is no automatic rollup in v1.** A Story does not flip to `done`
when its last Task does.

### The two axes — why the tree stops at three levels

These are deliberately **not** merged into one ladder:

- **Containment:** `Epic → Story → Task`. Three levels, hard stop.
- **Scheduling:** `Milestone` is a **flat, dated bucket**, not a level of the tree. Epics and
  Stories reference a milestone by id.

This is what keeps "what ships in v1.2?" a single indexed query instead of a recursive walk, and
it is why the tree never grows a fourth level.

---

## 4. Authorization — role-based access control

Authentication answers *who are you*. This section answers *what may you do*. They are separate
concerns; neither covers the other.

### Two tiers, because sign-up is disabled

- **`User#system_admin`** — a boolean, not a role. Can create users and projects. Deliberately
  tiny: a closed-signup app needs someone who can create the first account and first project, and
  nothing more.
- **`Membership#role`** — the real RBAC, scoped per project. A user can be `owner` of one project
  and `viewer` of another. All content permissions resolve through this.

**Exactly one owner per project**, enforced by validation, transferable. Without this rule a
project can be orphaned with nobody able to delete or transfer it.

### The permission matrix

This table is the single source of truth. The entire point of RBAC is that this question has one
answer in one place:

| Action | owner | admin | member | viewer |
|---|:---:|:---:|:---:|:---:|
| View project, epics, stories, tasks | ✓ | ✓ | ✓ | ✓ |
| Create / edit / delete epics, stories, tasks | ✓ | ✓ | ✓ | — |
| Create / edit / delete milestones | ✓ | ✓ | ✓ | — |
| Add & remove members, assign roles | ✓ | ✓ | — | — |
| Archive project | ✓ | ✓ | — | — |
| Transfer ownership, delete project | ✓ | — | — | — |

### Implementation

**Pundit**, one policy class per model: `ProjectPolicy`, `MembershipPolicy`, `MilestonePolicy`,
`EpicPolicy`, `StoryPolicy`, `TaskPolicy`. One policy maps to one test file, which fits the
per-class TDD rhythm in §9.

Enforce mechanically, the same way `NOT NULL` enforces the no-subtasks rule:

- **`after_action :verify_authorized` and `verify_policy_scoped`** in `ApplicationController`. A
  controller action that forgets to authorize **raises** rather than silently permitting. This
  converts "we remembered to check" into "it is impossible to forget."
- **Index actions go through Pundit scopes**, never a bare `Model.all`. Filtering happens in the
  query, not the view.

**Non-members get 404, not 403.** A 403 confirms the project exists. Rescue
`Pundit::NotAuthorizedError` to a 404 for non-members. A 403 is only correct for a member whose
role is too low — they already know the project exists.

### Edge cases that get explicit tests

Each carries an edge-case comment per §9:

- The last owner cannot be demoted or removed — it would orphan the project.
- An admin cannot demote or remove the owner.
- A viewer cannot mutate anything, including via a direct PATCH that skips the UI.
- A non-member gets 404 on a project they are not in, and it never appears in any index.
- A user's role in project A grants nothing in project B.

---

## 5. Security baseline

§4 is the largest security control in this app — most real breaches of a tool like this are
authorization failures, not exotic exploits. This section is everything else.

### These are CONFIRM tasks, not BUILD tasks

Rails already provides all of the following. **Verify they are on and move on.** Do not spend time
rebuilding them:

- **CSRF protection.** On by default; Turbo handles the token natively. **`skip_forgery_protection`
  is forbidden anywhere in this codebase.** The realistic failure mode is not forgetting to enable
  it — it is disabling it to unblock a form or `fetch` issue and never restoring it. If a request
  fails CSRF, the bug is in the request, not the protection.

- **Security headers — Rails' `default_headers` already sets these:** `X-Frame-Options: SAMEORIGIN`
  (clickjacking), `X-Content-Type-Options: nosniff`, `Referrer-Policy:
  strict-origin-when-cross-origin`, `X-Permitted-Cross-Domain-Policies: none`.
  **Do not write a headers middleware.** Verify they appear in a response.

- **HSTS comes free with `config.force_ssl = true`.** That one line turns on
  Strict-Transport-Security, upgrades cookies to `Secure`, and redirects http→https. It is one
  piece of work, not three.

- **Password hashing — `has_secure_password` (bcrypt).** It generates a unique salt per password
  and embeds it in the digest. **No manual salting is needed or wanted.**

  Use **`User.authenticate_by(email:, password:)`** — never `find_by` followed by `authenticate`.
  `authenticate_by` is constant-time with respect to whether the account exists, which is what
  actually enforces the generic-sign-in-failure rule below.

  Argon2id is the stronger algorithm and was considered. It was rejected because adopting it means
  replacing generated auth code with hand-written password handling and losing `authenticate_by`.
  **Do not hand-roll password hashing.**

- **Strong parameters.** `params.expect` / `permit` with an explicit column list. **`permit!` is
  forbidden** — it is mass assignment with extra steps, and here it would let a `viewer` PATCH a
  `role` column.

- **Output escaping.** ERB escapes by default. `html_safe` and `raw` on any user-supplied value
  are forbidden. User text is never trusted as markup.

- **Log filtering.** Confirm `filter_parameters` covers passwords and tokens before the first
  deploy — logs go to a server you now operate.

- **Cookies.** `SameSite=Lax` and `HttpOnly` are correct by default; `Secure` follows from
  `force_ssl`.

### CORS — deliberately NOT added

> **Do not add `rack-cors` or any CORS configuration.**
>
> CORS grants *other origins* access to this server. This is a same-origin server-rendered
> application: the browser loads HTML from this domain and posts back to this domain, so the
> policy never engages. Adding it hardens nothing — it only creates a way to widen access later
> by accident.
>
> If a genuine cross-origin consumer ever exists, that is a deliberate API project, not a config
> tweak.

This is stated explicitly because "add CORS" is a reflexive move when the word *security* appears.
Here, the correct action is the opposite.

### Must be added — Rails does not give these for free

- **Login rate limiting.** Rails 8+ ships `rate_limit` in ActionController. This is one line in the
  sessions controller, not a gem and not a subsystem:

  ```ruby
  rate_limit to: 10, within: 3.minutes, only: :create
  ```

  A publicly reachable password login without throttling is the single most likely way this app
  gets compromised. Build it in Phase 1, alongside auth.

  **No CAPTCHA, and that is a decision.** Sign-up is disabled, so the login form is the only public
  endpoint and the line above covers it. A CAPTCHA would put a third-party script in the login
  path — the same objection that ruled out a hosted identity provider. Revisit only if the rate
  limiter is observed being defeated in practice.

- **Content Security Policy.** Rails generates the initializer commented out. Enable it with nonces
  (`content_security_policy_nonce_generator`). Hotwire supports this, and `tailwindcss-rails`
  compiles to a real stylesheet so **no `unsafe-inline` is needed**.

  Roll out **report-only first** (Phase 7), then flip to enforcing before the Phase 8 deploy, so a
  broken directive surfaces as a report rather than a blank page.

- **`config.hosts`** set in production, blocking Host-header attacks. Rails only guards this in
  development by default.

- **`force_ssl = true`** in production — which is also what turns on HSTS and `Secure` cookies,
  per the CONFIRM list above.

- **Generic sign-in failures.** "Invalid email or password" — never distinguish which was wrong,
  or the login form becomes an account-enumeration oracle. This is only half the control:
  identical *wording* with non-identical *timing* still leaks, which is why `authenticate_by` is
  mandatory rather than optional.

- **Dependency scanning.** `bundler-audit` for gems, plus Dependabot. The generated CI workflow
  already runs `importmap audit` for JS and Brakeman for code. **Make all of them blocking, not
  advisory.**

### Security assertions are tests, not a checklist

Following §9's convention, these get real test cases with edge-case comments: a viewer PATCHing a
`role` directly is rejected; a sign-in attempt past the rate limit is throttled; sign-in failure
messages are identical for an unknown email and a wrong password.

### Deliberately out of scope

So their absence is a decision, not an oversight: 2FA/MFA, audit logging, account lockout, IP
allowlisting, penetration testing.

---

## 6. The non-negotiable constraint

> **There are no subtasks.**
>
> `tasks` has no `parent_id` column, no self-referential association, and no polymorphic parent.
> `Task` is a leaf. If a task feels like it needs children, it should have been a Story.
>
> **Do not add nesting "for flexibility."**

The `NOT NULL` on `tasks.story_id` is what makes this physically impossible rather than merely
discouraged. Keep it that way.

---

## 7. Routes, UI & accessibility

Nested resources (`/projects/:project_id/epics/:id`, etc.), shallow where sensible.

**Key screens:** project list; project backlog (the tree view — epics with nested stories and
tasks, collapsible); milestone list with progress; per-item detail page; archived project list
(§13 phase 5 — the project list filters to active, so archived projects need a screen of their
own to be restored from).

Inline status changes and inline create via Turbo Frames. Full page reloads are acceptable
everywhere else in v1.

### UI affordances included

- **Back-to-top button** — appears past a scroll threshold. Small Stimulus controller. The backlog
  tree gets long enough to justify it.
- **Loading indication: style Turbo's existing progress bar. Do not build one.** Turbo already
  shows `.turbo-progress-bar` automatically on navigation. Do not write a spinner system that
  duplicates what the framework provides.
- **Hover and focus states** — part of the Tailwind work, not a separately tracked feature.
- **Empty states** for a project with no epics and a search with no results.

### Accessibility — build these inline with the templates

Every item below is near-free *while you are writing the views* and expensive afterwards, because
a retrofit means reopening every template. **That timing, not difficulty, is why they are
specified up front.** Build them in Phase 5, not in a later polish pass.

- **Skip-to-content link** — visually hidden until focused, revealed by the first Tab, jumping past
  the nav to `<main>`. Use Tailwind's `sr-only` / `focus:not-sr-only`. (WCAG 2.4.1.)
- **Semantic landmarks** — real `<header>`, `<nav>`, `<main>` elements, not `<div>`s.
- **Visible focus rings** — **`outline: none` is forbidden.** Use `focus-visible:` variants.
- **`prefers-reduced-motion`** honored via Tailwind's `motion-reduce:` variant on anything that
  animates, including the back-to-top scroll.
- **Labelled form controls**, with validation errors associated to their input via
  `aria-describedby`. Do this once in a shared form partial.

### Deliberately not included

Turbo focus management on navigation, and `aria-live` announcements for Turbo Stream updates.

The known consequence, stated plainly: **screen reader users will not hear page changes announced
after a Turbo navigation.** This is an accepted gap, not an oversight. Revisit if anyone relying
on assistive technology uses this app.

**No scroll-progress bar.** It is an article-reading pattern with no meaning on a backlog, and it
would collide visually with Turbo's own top-pinned progress bar.

---

## 8. Site search

A real feature with a real hazard, not a polish item.

### The hazard, stated first

Search is the most common place authorization leaks in an app like this. The natural
implementation queries `Epic.where("title LIKE ?", q)` directly — bypassing every policy scope in
§4 and returning rows from projects the user cannot open.

**Every search query must run through `policy_scope`.** The **first test written in this phase**,
before any query code exists, is the leak test:

```ruby
# Search must never leak across project boundaries. A direct model query here
# would bypass Pundit entirely and expose titles from projects the user cannot
# open — the single most likely authorization hole in the app.
test "search excludes results from projects the user is not a member of" do
  # ...
end
```

### Implementation

SQLite **FTS5** virtual table over the titles and descriptions of epics, stories, and tasks, kept
in sync by triggers or model callbacks, with ranked results grouped by type. A single search box
in the header. Results scoped to projects the user can see, with the option to narrow to the
current project.

**Known exception to the Postgres-portability rule in §2.** FTS5 is SQLite-specific. If the
database is ever swapped, search is the piece that must be rewritten (to `tsvector`). This is
recorded here deliberately rather than discovered during a migration.

---

## 9. Development workflow — TDD

A strict red-green cycle, **per class, not per phase**:

> For every model, controller, policy, and helper: **write the test file first and run it to watch
> it fail**, then write the minimum implementation to make it pass, then refactor.
>
> **Never write implementation code for a class whose test file does not yet exist.**
>
> Do not batch. One class at a time, showing the failing output before the fix.

Two rules that keep this honest:

- **The failing test run must actually appear in output.** Do not assert that it happened.
- **A phase is not done** until `bin/rails test` is green *and* every new class has a
  corresponding test file.

### Test-comment convention

Every test case gets a comment above it naming the edge case or behavior it pins down — the
**why**, not a restatement of the test name:

```ruby
# A Task cannot outlive its Story: deleting the parent must cascade, otherwise
# orphan rows accumulate that no screen can reach or clean up.
test "destroying a story destroys its tasks" do
  # ...
end

# Guards the no-subtasks rule at the DB level. A NOT NULL story_id is what makes
# nesting physically impossible, so this fails loudly if a migration ever relaxes it.
test "task is invalid without a story" do
  # ...
end
```

### Coverage expectations

Per model: validations, each association's `dependent:` behavior, enum transitions, and the
scoping/ordering used by the backlog view.

Controllers get request tests for auth (signed-out redirect) and for non-members being denied
access to a project.

---

## 10. Version control & commit conventions

### Standing authorization

You have permission to commit at the boundaries below **without asking each time**. Pushing to a
remote and deploying are **not** covered and still require an explicit request.

### When to commit — one commit per completed red-green-refactor cycle

The commit contains **the test and the implementation together**, made once the suite is green.

**The failing test does not get its own commit.** "Commit the red test first" sounds more faithful
to TDD, but a commit with a failing suite breaks `git bisect` and turns CI red on a commit that
was never meant to be green. Every commit should be a working state.

The rhythm: write failing test → show it fail → implement → run it → adjust the implementation if
it's wrong → suite green → **commit** → next class.

### When the bug turns out to be in a different class

While working on class A you discover the real defect is in class B. **Default: two commits, B
first.**

```text
fix(story): return stories in position order      ← commit 1, class B
feat(task): add Task with story association       ← commit 2, class A
```

Why split rather than bundle: the two halves have different Conventional Commit *types* — one is a
`fix`, the other a `feat` — so bundling forces a type that is wrong for half the diff. A standalone
`fix` is also independently revertable, which matters precisely when that fix is what broke
something else later.

**The B-fix commit carries its own regression test.** The fix to class B is itself a red-green
cycle: write a test reproducing B's bug and watch it fail, fix B, commit test and fix together. A
`fix` commit with no test is not evidence the bug is gone.

**The exception — bundle instead.** If B's defect only *becomes* a defect because of A's new code
(B was never wrong until something used it this way), a standalone B commit cannot be meaningfully
tested on its own. Bundle both into A's commit. The test is whether the B fix stands up as an
independent, testable change; if it doesn't, it isn't one.

### Format — Conventional Commits

`<type>(<scope>): <subject>`

- **Types:** `feat`, `fix`, `test`, `refactor`, `docs`, `chore`, `ci`, `build`, `perf`, `style`.
- **Scope:** the domain object or area — `epic`, `story`, `task`, `milestone`, `project`, `auth`,
  `backlog`, `search`, `deploy`.
- **Subject:** imperative mood, lowercase, no trailing period, ≤72 chars.
- Body explains *why* when the change isn't self-evident. Breaking changes use `!` after the scope
  plus a `BREAKING CHANGE:` footer.

```text
feat(epic): add Epic model with optional milestone association
test(task): cover NOT NULL story_id enforcing the no-subtasks rule
fix(backlog): order stories by position instead of id
refactor(story): extract status transition into a concern
ci(actions): run system tests and upload failure screenshots
docs(readme): document the Kamal deploy and restore procedure
chore(deps): bundle update after rails install
```

Note the pairing: because test and implementation land in one commit, a `feat(...)` commit is
**expected to contain test files too**. The `test(...)` type is for adding coverage to code that
already exists.

### Branching

A branch per phase (`phase-1-auth-and-projects`), opened as a PR into `main`, CI green before
merge. This matches the CI triggers in §11 and keeps `main` always deployable. Direct commits to
`main` are reserved for the initial `rails new`.

### Never commit

`config/master.key`, `.env`, the SQLite files in `storage/`, anything under `tmp/`. Confirm
`rails new`'s generated `.gitignore` already covers these before the first commit.

### Optional but recommended

Add `commitlint` with `@commitlint/config-conventional` as a CI job. Node 22 is already present.
This enforces the format mechanically rather than by discipline — consistent with how the schema
enforces the no-subtasks rule.

---

## 11. CI — GitHub Actions

Recent Rails versions scaffold `.github/workflows/ci.yml` as part of `rails new`, arriving with
Brakeman, RuboCop (omakase), importmap audit, and a test job already wired.

**Check whether the generated workflow exists first, and extend it rather than writing one from
scratch.** Only author a workflow yourself if it is absent. (This is a check rather than an
assumption, because the installed Rails version is not known in advance.)

Required additions:

- Run `bin/rails test` **and** `bin/rails test:system`. Confirm the system-test job's SQLite setup
  and upload screenshot artifacts on failure.
- Trigger on `push` to `main` and on all pull requests.
- Cache gems via `ruby/setup-ruby` with `bundler-cache: true`.
- Make Brakeman, `bundler-audit`, and `importmap audit` **blocking**.
- Fail the build on a missing test file for any new model — a simple guard script, or at minimum a
  documented reviewer check.

`rails new` initializes git, so the repo is created in Phase 1. Creating the GitHub remote and
pushing is the human's job — **CI is inert until a remote exists.**

---

## 12. Deployment

Rails 8+ generates a `Dockerfile`, Kamal config, and Thruster as part of `rails new`. Same policy
as CI: **check what was generated and configure it, rather than inventing a deploy pipeline.**

Requirements:

- **Kamal** deploy to a single VPS. Leave the target host as a placeholder for the human to fill in.
- **A persistent volume** mounted for `storage/`, where the SQLite database lives.

  This is the most important line in this section: **a container redeploy without it silently
  destroys every project, epic, story, and task.**

- **Backups** — a scheduled `sqlite3 .backup` (or Litestream) to off-box storage, plus a
  documented, **actually-tested** restore procedure. A backup nobody has restored is not a backup.
- `RAILS_MASTER_KEY` supplied as a deploy secret. `config/master.key` never committed.
- `force_ssl` enabled in production.
- README documents the full deploy sequence and how to create the first user.

### Getting teammates in

Open sign-up is **disabled**. A project owner or admin adds an **existing** user to a project by
email address. Emailed invitations with tokens are out of scope — they need mailer configuration
and a deliverability story, which is a project of its own.

### Continuous deployment — gated, built last (Phase 9)

Merging to `main` builds and pushes the image and runs every check, then **stops at a GitHub
Environment approval gate**. A human clicks deploy. **Migrations never run unattended.**

The ordering is deliberate: **Phase 8 deploys manually** and verifies a restore; **Phase 9 then
automates the exact sequence already proven by hand.** Automating an unproven deploy means
debugging the app and the pipeline simultaneously, with no way to tell which is at fault.

The pipeline, in order — the backup step is not optional:

```text
merge to main
  └ CI: tests, system tests, brakeman, rubocop
  └ build image → push to registry
  └ ⏸  GitHub Environment: required reviewer  ⏸
  └ sqlite3 .backup  ← BEFORE migrations, every time
  └ bin/rails db:migrate
  └ kamal deploy  (health check, zero-downtime)
```

**Why the gate.** SQLite on a single node has no replica and no point-in-time restore — rollback
means restoring a file copy while users wait. That makes an unattended bad migration materially
worse here than it would be on managed Postgres. That is the entire justification for a human in
the loop.

**Secrets this requires in GitHub**, enumerated so the security surface is explicit rather than
discovered: an SSH private key for the VPS (Kamal deploys over SSH), container registry
credentials, and `RAILS_MASTER_KEY`. This means **a compromised GitHub account reaches the
production server.** Use a deploy-only SSH key, not a personal one.

**Rollback** is `kamal rollback` for code. A database rollback is the restore procedure above —
which is why Phase 8 requires actually testing it.

---

## 13. Phases

Each phase follows the red-green cycle internally, ends with `bin/rails test` green and CI config
valid, and then **stops for human review before the next phase begins.**

1. **Setup & auth.** `gem install rails` → record the version → `rails new` → auth **with login
   rate limiting** → `Project` → `Membership`. Extend the CI workflow with Brakeman,
   `bundler-audit`, and `importmap audit` all **blocking**, passing locally.

2. **`Milestone` + `Epic`.**

3. **`Story` + `Task`.** Re-read §6 before starting: no subtasks, no `parent_id`, `story_id` is
   `NOT NULL`.

4. **RBAC.** Pundit, one policy per model, the §4 permission matrix implemented and tested
   role-by-role, `verify_authorized` turned on, Pundit scopes on every index, plus the
   member-management UI.

   This is its own phase because it is what makes this a team app rather than a single-user one —
   and because **turning on `verify_authorized` will break every controller written in Phases
   1–3.** That is the point. Fixing those breakages is the phase's work.

5. **Backlog tree view + status changes**, with system tests for the main flow.
   **Build the §7 accessibility items here, inline with the templates** — skip link, landmarks,
   focus rings, `motion-reduce:`, labelled controls. They are near-free now and a five-view
   retrofit later.

   **Also build the project archive and delete screens here**, closing §4 matrix rows 5 and 6.
   Phase 4 implemented and tested `ProjectPolicy#archive?` and `#destroy?` and left both with no
   caller — the matrix grants them and no phase built the UI, which was an omission in this
   document rather than a deferral. They land in this phase for the same timing reason the
   accessibility items do: a screen built after this phase is a screen the accessibility pass has
   to be retrofitted onto. Waiting also means Phase 8 deploys to a real server on which the only
   way to retire a project is the Rails console.

   Two decisions this needs, neither of which is made above:

   - The project list filters to `active`, so **archiving must come with a way to see and restore
     archived projects.** Otherwise it is a one-way trip that hides the project from the only
     screen that could bring it back.
   - Deleting cascades through epics, stories and tasks. It needs a confirmation that says what
     is about to be destroyed, not a bare "are you sure?".

   `resources :projects` already routes `DELETE` to a `destroy` action that does not exist, so
   that URL currently renders 404. Building the screen closes it.

6. **Site search.** FTS5 table, search UI, results grouped by type. **Write the cross-project leak
   test from §8 first**, before any query code exists.

7. **Seeds & polish.** Seed data using generic placeholder users, Tailwind polish, back-to-top
   button, empty states, styled `.turbo-progress-bar`, README. Enable **CSP in report-only mode** —
   early enough that violations surface while there is still UI work in flight to fix them.

8. **Hardening, then manual deploy.** Flip CSP from report-only to enforcing. Set `config.hosts`,
   `force_ssl`; confirm `filter_parameters`. Then Kamal config, persistent volume, backups, first
   real deploy, and a **restore actually performed and verified**, not merely documented.

9. **CD.** Automate exactly the Phase 8 sequence: build on merge to `main`, GitHub Environment
   approval gate, pre-migration backup, `kamal deploy`. Verify by shipping one trivial change (a
   README line) through the full pipeline end to end.

---

## 14. Out of scope for v1

**Do not add these**, however helpful it seems: subtasks, Kanban board with drag & drop, comments
and activity feed, labels and saved filters, story points and burndown, Jira-style `ACME-14`
reference keys, notifications, emailed invitations, attachments, multi-tenancy, public API,
native/desktop packaging, offline support, scroll-progress bar.

### Decided against, with the trigger that would reverse it

These are conclusions, not omissions. They are recorded so they are not silently re-added:

- **Cookie consent banner.** This app sets one cookie: the session cookie that keeps a user signed
  in. Strictly-necessary cookies are exempt from consent requirements, and the app is login-gated,
  so there is no anonymous visitor to consent to anything. A banner would be ritual, and it trains
  users to dismiss consent dialogs without reading them.

  **Trigger:** the moment analytics or any third-party cookie is introduced, a banner becomes
  required — and it must gate the script from loading, not merely announce it.

- **CORS / `rack-cors`.** See §5. Same-origin app; adding it widens access rather than restricting
  it. **Trigger:** a genuine cross-origin consumer, which would be a deliberate API project.

- **Turbo focus management and `aria-live` stream announcements.** Known consequence: **screen
  reader users will not hear page changes announced after a Turbo navigation.**
  **Trigger:** anyone relying on assistive technology using this app — at which point this becomes
  a priority fix, not a nice-to-have.

- **`axe-core` in system tests.** Would make accessibility regressions fail CI.
  **Trigger:** taking on the full accessibility pass.

- **Argon2id password hashing.** See §5. **Trigger:** a requirement that mandates it — at which
  point migrate by rehashing on next successful login, so users move over without a forced reset.
