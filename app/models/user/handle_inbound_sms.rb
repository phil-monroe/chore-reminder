class User::HandleInboundSms
  HELP_TEXT = "Reply DONE, SKIP, NEXT, LIST, ADD <task name>, or SNOOZE (until tomorrow / for <N> hours / until <N>am|pm).".freeze
  MAX_LIST_SIZE = 20
  SNOOZE_USAGE = "Sorry, I didn't understand that. Try \"SNOOZE until tomorrow\", \"SNOOZE for 2 hours\", or \"SNOOZE until 4pm\".".freeze

  def initialize(user:, body:, deliver_reply: false, sender: nil)
    @user = user
    @body = body.to_s.strip
    @deliver_reply = deliver_reply
    @sender = sender
  end

  def call
    @user.messages.create!(direction: :inbound, body: @body)

    reply = dispatch
    if @deliver_reply
      User::SendMessage.new(user: @user, body: reply, sender: @sender).call
    else
      @user.messages.create!(direction: :outbound, body: reply)
    end

    # Enqueued here, after the reply itself is sent/logged, rather than from
    # within dispatch's mark_done/skip/add — GoodJob runs async jobs
    # in-process, so enqueuing any earlier risks NotifyNextTaskChangedJob's
    # own message landing (and rendering) before this reply's, despite
    # happening logically first.
    NotifyNextTaskChangedJob.perform_later(@user.id, @previous_next_task_id) if @notify_next_task_changed
    reply
  end

  private

  # The real Twilio webhook (Integrations::TwilioController) never sets
  # deliver_reply: the reply text goes back as the TwiML response, and
  # Twilio itself delivers that as the SMS — so it's just logged here
  # directly rather than re-sent via User::SendMessage/Sms::TwilioSender.
  # The web UI's "simulate a text reply" form has no such webhook response
  # to ride along on, so it sets deliver_reply: true to actually send (and
  # log) the reply as a real outbound text, the same as any other message.
  def dispatch
    case @body
    when /\Adone\z/i then mark_done
    when /\Askip\z/i then skip
    when /\Anext\z/i then list_next
    when /\Alist\z/i then list_all
    when /\Aadd\s+(.+)\z/i then add($1)
    when /\Asnooze\s+(.+)\z/i then snooze($1)
    when /\Asnooze\z/i then SNOOZE_USAGE
    else
      "Sorry, I didn't understand that. #{HELP_TEXT}"
    end
  end

  def mark_done
    task = Task.next_for(@user)
    return "You don't have any pending tasks." if task.nil?

    task.update!(done: true)
    notify_if_next_task_changed(previous_next_task_id: task.id)
    "Marked \"#{task.name}\" done."
  end

  def skip
    task = Task.next_for(@user)
    return "You don't have any pending tasks." if task.nil?

    task.move_to_bottom
    notify_if_next_task_changed(previous_next_task_id: task.id)
    "Skipped \"#{task.name}\"."
  end

  # Kept deliberately separate from NEXT (top 5) rather than merged: NEXT is
  # the low-key default for a household member who can get overwhelmed by
  # seeing everything at once, while LIST is an explicit ask to see the
  # full list when they want it.
  def list_next
    tasks = @user.tasks.pending.order(:position).limit(5)
    return "You don't have any pending tasks." if tasks.empty?

    tasks.each_with_index.map { |task, index| "#{index + 1}. #{task.name}" }.join("\n")
  end

  def list_all
    tasks = @user.tasks.pending.order(:position)
    return "You don't have any pending tasks." if tasks.empty?

    lines = tasks.limit(MAX_LIST_SIZE).each_with_index.map { |task, index| "#{index + 1}. #{task.name}" }
    remaining = tasks.count - lines.size
    lines << "...and #{remaining} more." if remaining > 0
    lines.join("\n")
  end

  def add(name)
    previous_next_task_id = Task.next_for(@user)&.id
    @user.tasks.create!(name: name)
    notify_if_next_task_changed(previous_next_task_id: previous_next_task_id)
    "Added \"#{name}\" to your list."
  end

  # Pauses reminders (scheduled sends and realtime next-task notifications —
  # see User#snoozed?, SendReminderJob, User::NotifyIfNextTaskChanged) until
  # a point in time, without touching ReminderDefinition's own schedule, so
  # snoozing has no effect on what's "next" once it lapses.
  def snooze(args)
    case args.strip
    when /\Auntil\s+tomorrow\z/i
      apply_snooze(tomorrow_5am)
    when /\Afor\s+(\d+)\s*hours?\z/i
      apply_snooze(Time.current + $1.to_i.hours)
    when /\Auntil\s+(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m\.?\z/i
      apply_snooze(next_occurrence_of(hour: $1.to_i, minute: $2.to_i, meridiem: $3))
    else
      SNOOZE_USAGE
    end
  end

  def apply_snooze(time)
    @user.update!(snoozed_until: time)
    "Reminders snoozed until #{time.in_time_zone(@user.time_zone_object).strftime("%-I:%M %p on %b %-d")}."
  end

  def tomorrow_5am
    zone = @user.time_zone_object
    zone.now.change(hour: 5, min: 0, sec: 0) + 1.day
  end

  def next_occurrence_of(hour:, minute:, meridiem:)
    zone = @user.time_zone_object
    hour %= 12
    hour += 12 if meridiem.downcase.start_with?("p")
    candidate = zone.now.change(hour: hour, min: minute, sec: 0)
    (candidate > zone.now) ? candidate : candidate + 1.day
  end

  # Records that NotifyNextTaskChangedJob should fire for this previous next
  # task id, rather than enqueuing it immediately — see the comment in #call
  # on why the actual enqueue is deferred until after the reply is sent.
  # Fires asynchronously (rather than folding "next up: ..." into this
  # command's own reply) so DONE/SKIP/ADD all funnel through the same
  # next-task-changed notification as web UI changes (see TasksController) —
  # one mechanism instead of two copies of the "did the next task change"
  # comparison.
  def notify_if_next_task_changed(previous_next_task_id:)
    @notify_next_task_changed = true
    @previous_next_task_id = previous_next_task_id
  end
end
