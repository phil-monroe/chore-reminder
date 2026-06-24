# How To

A task-by-task guide to using Chore Reminder as a caregiver. See [FEATURES.md](FEATURES.md) for a higher-level overview of what the app does.

Everything below except "Reply to a reminder by text" happens in the admin area, reached by opening the app and logging in with the shared caregiver password. The dashboard is the home screen, listing every household member with their next task; open a household member's name to get to their own page.

From a household member's page, the **⋯** menu next to their name has links to their task definitions, reminders, conversation history, message sending, completed tasks, and settings — most of the steps below start there. Each task row also has its own **⋯** menu, for editing or deleting that task.

## Add a household member

1. From the dashboard, click **Add user** below the list of household members (or **Add one** if there are no users yet).
2. Fill in their name, phone number (in `+1XXXXXXXXXX` international format), and time zone.
3. Optionally set a `username` — a friendly identifier used in their public task links instead of a numeric id. Lowercase letters, numbers, underscores, and hyphens only.
4. Optionally adjust their message template — see "Customize someone's reminder wording" below. A sensible default is filled in for you.
5. Save. You can send them a welcome text afterward from their user page.

## Add a one-off task

1. Open the household member's page — their incomplete tasks are listed right there.
2. Click **New task** and give it a name. Optionally, set a time estimate (in minutes) so they know what to expect.
3. It's added to the bottom of their list. Use the ↑/↓ buttons to reorder it if it needs to happen sooner.

## Set up a recurring task

Use this for chores that repeat on a schedule (e.g. "take out the trash every Monday and Thursday") instead of re-adding the same task by hand each time.

1. From the household member's page, open the **⋯** menu and choose **Task Definitions**, then create a new one.
2. Give it a name and, optionally, a Markdown description and photos — these show up on the task's public page, linked from the reminder text.
3. Set a time of day, pick which days of the week it recurs on, and optionally a time estimate (in minutes) — carried over to each task it generates.
4. Save. A matching task is generated automatically each day it's scheduled, but only if the previous instance has already been marked done — so an unfinished one is never duplicated.
5. To generate today's task immediately (e.g. to test it) without waiting for the schedule, use **Generate now** on the task definition's page.

## Schedule reminder texts

1. From the household member's page, open the **⋯** menu and choose **Reminders**, then create a new one.
2. Set the time of day reminders should go out. You can add multiple reminder times per day by creating more than one.
3. At each scheduled time, they'll be texted their current next pending task. If they have nothing pending, no text is sent.
4. To send a reminder right away (e.g. to test it), use **Send now** on the reminder definition's page.

## Reorder or complete tasks

- On the dashboard, each household member's card shows their next task with a quick **Mark done** button.
- On a household member's page, every incomplete task is listed with ↑/↓ buttons to reorder it, and a green checkmark button to mark it done. Once done, that button turns into a muted "undo" icon you can click to mark it incomplete again.
- A household member's page also shows their incomplete task count and how many tasks they've completed in the last 7 and 30 days, and in total.
- To review completed tasks, open the **⋯** menu next to the household member's name and choose **Completed Tasks** — they're grouped by the day they were finished, going back two weeks.

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

1. Open the household member's page, then open the **⋯** menu and choose **Conversation**.
2. Use the form at the bottom to type what they would have said (e.g. `done`, `add take out recycling`).
3. It's handled exactly like a real text reply, and the actual reply is sent back to them as a real text — so this isn't just a preview.

## View someone's text history

Open the household member's page, then open the **⋯** menu and choose **Conversation** to see every text exchanged with them, oldest first, with inbound replies and outbound texts visually distinguished.

## Send a one-off or welcome message

From a household member's page, open the **⋯** menu:
- **Send message** sends an arbitrary one-off text, unrelated to any chore.
- **Send welcome message** sends a canned introductory text — useful the first time someone starts getting reminders.

## Customize someone's reminder wording

Each household member has a message template (in [Liquid](https://shopify.github.io/liquid/) syntax) controlling how their reminder texts read. Open the **⋯** menu on their page and choose **User Settings** to edit it. Three variables are available:

- `{{ task_name }}` — the name of their current task
- `{{ time_estimate }}` — how long the task is expected to take, if a time estimate was set on it
- `{{ link }}` — a link to the task's public page, if it has one (recurring tasks do; one-off tasks don't)

The default template is:

```
Up next: {{ task_name }}{% if time_estimate %} ({{ time_estimate }}){% endif %}
{% if link %}{{ link }}{% endif %}
```

## Open the public page for a task

Recurring task definitions get a public, no-login page at a URL like `/<username>/<task-slug>`, automatically linked from reminder texts for that task. It shows the task's name, Markdown description, and any photos.

## Connect Claude to manage chores

1. In the Claude app, add Chore Reminder as a connector, pointing it at this app's address.
2. Claude will open this app's login page if you're not already signed in - log in with the shared caregiver password.
3. Choose which household member this connection should act as by default (e.g. yourself, or the household member you'll be asking about most), then continue. You can still ask Claude to manage any household member - this just sets who it assumes when you don't say.
4. You're connected. Try asking Claude things like "what's on my list today?", "mark take out the trash done", or "add a recurring task for watering the plants every Monday at 9am".

## Disconnect a connected app

1. Open the **Connected apps** link in the admin navigation.
2. Find the app (e.g. Claude) and click **Disconnect**. This immediately revokes its access - it can no longer view or change anything until reconnected.

## Check on background job activity

The job runner that sends scheduled reminders and generates recurring tasks has its own dashboard at `/admin/good_job`, behind the same caregiver login as the rest of the admin area. Use it to see recent and upcoming job runs, or to investigate a failed send.
