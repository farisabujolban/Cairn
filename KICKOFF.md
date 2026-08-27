# Kickoff prompt

Paste the block below into a fresh Claude Code session opened in this directory.

---

Read `SPEC.md` in this directory completely before doing anything. It is the source of truth for
this project and it already contains every decision — stack, domain model, authorization,
security, phases. Do not re-derive them.

You are building a **server-rendered Rails web application** — Hotwire, no separate frontend —
that will be **deployed to a server for a small team to sign in over the internet**. Production is
containerized via Kamal; local development runs natively with no Docker Compose.

This directory is empty and **Rails is not installed yet**. Ruby 4.0.5 and Node 22 are present.
Phase 1 starts with `gem install rails`.

Three rules that matter more than anything else, restated here because they erode over a long
build:

1. **Strict TDD.** Write the test file first, run it, and **show the failing output** before
   writing any implementation. Never write implementation code for a class whose test file does
   not yet exist. Every test case gets a comment naming the edge case it covers.
2. **No subtasks, ever.** `Task` is a leaf. `tasks.story_id` is `NOT NULL` and there is no
   `parent_id` column. Do not add nesting "for flexibility."
3. **Commit per green cycle**, Conventional Commits format (`feat(epic): ...`), test and
   implementation together, only once the suite passes. You have standing permission to commit;
   pushing and deploying still require asking.

Work through the phases in `SPEC.md` §13 **in order**. **Re-read `SPEC.md` at the start of every
phase** — the constraints matter most at the moment you are about to violate them. At the end of
each phase, run the full test suite and **stop for review** before starting the next.

If you think one of the stack decisions is wrong, or a required generator does not exist in the
installed Rails version, **ask** — do not silently substitute an equivalent.

Start with Phase 1.
