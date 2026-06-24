# How To

A task-by-task guide to using Chore Reminder as a caregiver. See [FEATURES.md](FEATURES.md) for a higher-level overview of what the app does.

Everything below except "Reply to a reminder by text" happens in the admin area, reached by opening the app and logging in with the shared caregiver username/password.

## Add a household member

1. From the dashboard, go to **Users** and click **Add one** (or **New user** on the users list).
2. Fill in their name, phone number (in `+1XXXXXXXXXX` international format), and time zone.
3. Optionally set a `username` — a friendly identifier used in their public task links instead of a numeric id. Lowercase letters, numbers, underscores, and hyphens only.
4. Optionally adjust their message template — see "Customize someone's reminder wording" below. A sensible default is filled in for you.
5. Save. You can send them a welcome text afterward from their user page.

## Add a one-off task

1. Open the household member's page and go to their task list.
2. Click to add a new task and give it a name.
3. It's added to the bottom of their list. Use the up/down controls to reorder it if it needs to happen sooner.

## Set up a recurring task

Use this for chores that repeat on a schedule (e.g. "take out the trash every Monday and Thursday") instead of re-adding the same task by hand each time.

1. From the household member's page, go to **Task definitions** and create a new one.
2. Give it a name and, optionally, a Markdown description and photos — these show up on the task's public page, linked from the reminder text.
3. Set a time of day and pick which days of the week it recurs on.
4. Save. A matching task is generated automatically each day it's scheduled, but only if the previous instance has already been marked done — so an unfinished one is never duplicated.
5. To generate today's task immediately (e.g. to test it) without waiting for the schedule, use **Generate now** on the task definition's page.

## Schedule reminder texts

1. From the household member's page, go to **Reminder definitions** and create a new one.
2. Set the time of day reminders should go out. You can add multiple reminder times per day by creating more than one.
3. At each scheduled time, they'll be texted their current next pending task. If they have nothing pending, no text is sent.
4. To send a reminder right away (e.g. to test it), use **Send now** on the reminder definition's page.

## Reorder or complete tasks from the dashboard

On a household member's task list, use the up/down arrows to move a task, or the checkbox/button to mark it done. The dashboard's "next task" card updates immediately. Completed tasks can be viewed separately via the "done" filter on the task list.

## Reply to a reminder by text

A household member can reply directly to a reminder text — no login needed:

| Reply | Effect |
|---|---|
| `DONE` | Marks their current (top) task done |
| `SKIP` | Moves their current task to the bottom of the list |
| `NEXT` | Lists their next 5 pending tasks |
| `LIST` | Lists all pending tasks |
| `ADD <name>` | Adds a new task, e.g. `ADD water the plants` |
| `SNOOZE until tomorrow` | Pauses reminders until 5am tomorrow (in their time zone) |
| `SNOOZE for <N> hours` | Pauses reminders for N hours, e.g. `SNOOZE for 3 hours` |
| `SNOOZE until <N>am` / `<N>pm` | Pauses reminders until a specific time, e.g. `SNOOZE until 4pm` |
| `UNSNOOZE` | Cancels an active snooze |

Replies are case-insensitive. An unrecognized reply gets a short list of valid commands.

## Simulate a text reply from the web UI

Useful when you're physically with the household member rather than texting them.

1. Open the household member's page and go to **Conversation**.
2. Use the form at the bottom to type what they would have said (e.g. `done`, `add take out recycling`).
3. It's handled exactly like a real text reply, and the actual reply is sent back to them as a real text — so this isn't just a preview.

## View someone's text history

Open the household member's page and go to **Conversation** to see every text exchanged with them, oldest first, with inbound replies and outbound texts visually distinguished.

## Send a one-off or welcome message

From a household member's page:
- **New message** sends an arbitrary one-off text, unrelated to any chore.
- **Send welcome message** sends a canned introductory text — useful the first time someone starts getting reminders.

## Customize someone's reminder wording

Each household member has a message template (in [Liquid](https://shopify.github.io/liquid/) syntax) controlling how their reminder texts read. Edit it from their user form. Two variables are available:

- `{{ task_name }}` — the name of their current task
- `{{ link }}` — a link to the task's public page, if it has one (recurring tasks do; one-off tasks don't)

The default template is:

```
Up next: {{ task_name }}
{% if link %}{{ link }}{% endif %}
```

## Open the public page for a task

Recurring task definitions get a public, no-login page at a URL like `/<username>/<task-slug>`, automatically linked from reminder texts for that task. It shows the task's name, Markdown description, and any photos.

## Check on background job activity

The job runner that sends scheduled reminders and generates recurring tasks has its own dashboard at `/admin/good_job`, behind the same caregiver login as the rest of the admin area. Use it to see recent and upcoming job runs, or to investigate a failed send.
