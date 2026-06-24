---
name: sync-docs
description: Use after any change to user-facing behavior (a new SMS command, a new admin screen, a new model field/option, a changed schedule or workflow) to keep FEATURES.md and HOW_TO.md in sync with the actual app, and to check whether the doc-serving routes/views still match. Also use when explicitly asked to update or check the help/features docs.
---

# Keeping FEATURES.md and HOW_TO.md in sync

This repo publishes two docs as part of the product itself, not just contributor reference:

- `FEATURES.md` — a marketing-style overview of what the app does. Served at `GET /` via `PagesController#home` / `Views::Pages::Home`.
- `HOW_TO.md` — a how-to knowledge base, one section per task a caregiver or household member would actually do. Served at `GET /help` via `PagesController#help` / `Views::Pages::Help`.

Both routes render these exact files through `Commonmarker.to_html` (see `PagesController#rendered_doc`) — there's no separate copy of the content baked into a view, so editing the `.md` files is the only thing needed to change what's published. There's also a "Help" link in the admin navbar (`Views::Layouts::ApplicationLayout#render_nav`) pointing at `/help`.

## When to update these docs

Treat any of the following as a signal that `FEATURES.md` and/or `HOW_TO.md` are now stale, and update them in the same change:

- A new or changed inbound SMS command (`User::HandleInboundSms` — currently `DONE`/`SKIP`/`NEXT`/`LIST`/`ADD`/`SNOOZE`/`UNSNOOZE`).
- A new or changed admin screen, form field, or action (anything under `app/controllers/admin/`).
- A new model concept or changed validation that changes what a caregiver can configure (e.g. a new `User`/`Task`/`TaskDefinition`/`ReminderDefinition` field, a new recurrence option).
- A changed schedule or job behavior that affects when/how reminders or recurring tasks fire (`config/initializers/good_job.rb`, `app/jobs/`).
- A new public-facing page or change to what a household member without admin credentials can see.

A change that's purely internal (refactoring, a bug fix with no behavior change, test/CI/Docker tooling) does **not** need a docs update.

## How to update them

1. Read the relevant model/controller/command class to understand the actual current behavior — don't guess from the doc's existing wording.
2. `FEATURES.md`: add or edit one `##` section per feature, written as a short, user-facing capability description (what it does and why it's useful), not implementation detail. Keep it scannable — a caregiver evaluating the app reads this, not a developer.
3. `HOW_TO.md`: add or edit one `##` section per task, written as numbered steps a caregiver (or, for SMS replies, a household member) would actually follow. Reuse the existing section headings/style as a template — e.g. "Set up a recurring task" walks through every field in order.
4. If the change adds a genuinely new top-level feature (not a tweak to an existing one), add a new section to both files rather than overloading an existing one.
5. After editing, sanity-check rendering:
   - `bin/dev/run-web` (or `run-all`) if not already running.
   - Visit `/` and `/help` and confirm the new section renders as expected (headings, lists, code blocks) — Commonmarker is plain CommonMark, so check anything with nested lists or tables in particular.
6. Run `bin/dev/run-tests test/controllers/pages_controller_test.rb` — it asserts on specific strings from both docs, so a heading rename there is a deliberate signal to check whether that test's assertions need updating too.
7. Run `bin/standardrb` if you touched any Ruby files (controller/views), per this repo's lint setup.

## Don't

- Don't duplicate the doc content into the Phlex views (`Views::Pages::Home`/`Views::Pages::Help`/`Views::Pages::Base`) — they render the `.md` files directly. If the rendered output looks wrong, the fix belongs in the Markdown or in `Views::Pages::Base`'s shared layout, not a per-page copy.
- Don't write implementation detail (class names, job names, table columns) into either doc — that belongs in `CLAUDE.md`/code comments. These two files are for the people *using* the app, not developing it.
