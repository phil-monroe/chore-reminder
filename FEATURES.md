# Features

Chore Reminder helps a caregiver keep a household member's chore list up to date and texts them the next thing to do — no app to install, just SMS.

## Per-person chore lists

Every household member is a `User` with their own ordered list of tasks. A caregiver adds tasks, reorders them (move up/down), and marks them done from the admin dashboard. The top pending task is always "what's next" for that person.

## Text message reminders

Each person can have one or more scheduled reminder times per day. At each scheduled time, the app texts them their current next task via Twilio. If they don't have a pending task, no text is sent. Reminders pause automatically while a person has snoozed (see below).

## Recurring tasks

Instead of adding the same chore by hand every week, a caregiver can define a recurring task definition: a name, an optional Markdown description, optional photos, a time of day, and which days of the week it recurs on. The app generates a fresh task automatically on each scheduled day — but only if the previous instance has already been completed, so an unfinished chore never gets duplicated.

## Reply by text

A household member can reply to any reminder text to manage their own list, without touching the web app:

- `DONE` — marks their current task done
- `SKIP` — moves their current task to the bottom of the list
- `NEXT` — lists their next 5 pending tasks
- `LIST` — lists all pending tasks
- `ADD <name>` — adds a new task to their list
- `SNOOZE until tomorrow` / `SNOOZE for <N> hours` / `SNOOZE until <N>am|pm` — pauses scheduled reminders until that time
- `UNSNOOZE` — cancels an active snooze

## Real-time "what's next" updates

Whenever a change could affect what a person's next task is — completing, skipping, adding, editing, deleting, or reordering a task, or a recurring task generating for the day — the app checks right away and, if the next task actually changed, texts them immediately instead of waiting for the next scheduled reminder (up to 15 minutes later).

## Public per-task page

Every recurring task definition has its own simple, unauthenticated web page (linked from reminder texts) showing its name, Markdown-rendered description, and any photos — so a household member can tap the link in a text to see instructions or a reference photo without logging into anything.

## Conversation history

The admin area has a chat-style view of every text exchanged with a household member, oldest first, so a caregiver can see exactly what was sent and what they replied. A caregiver can also simulate a text reply from this view — useful when standing next to the person rather than texting them — which runs the same DONE/SKIP/NEXT/LIST/ADD/SNOOZE handling as a real text and actually sends the reply.

## Custom message wording

Each person has their own message template (using [Liquid](https://shopify.github.io/liquid/) syntax) controlling exactly how their reminder texts are worded, with the task name and (when available) a link to the task's public page available as template variables.

## Per-person time zone

Each household member has their own time zone, so a recurring task's "time of day" and a reminder's "time of day" are both evaluated in *their* local time, not the server's.

## One-off and welcome messages

A caregiver can send an arbitrary one-off text to a household member (e.g. a heads-up unrelated to any chore), or send a canned welcome message to introduce someone to text-based reminders for the first time.

## Single shared login

There are no individual accounts. The entire admin area is gated by one shared password for the caregiver(s) managing the household, entered on a simple login page. Reminder texts, their linked public task pages, and this help/features site all require no login at all.

## Self-hosted, single container

The whole app — web server and background job processing — runs as a single Docker container with no separate worker process, message queue, or external cache to manage. Designed to run on a home server for one household.
