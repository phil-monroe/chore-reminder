require "test_helper"

class User::HandleInboundSmsTest < ActiveSupport::TestCase
  class FakeSender
    attr_reader :calls

    def initialize
      @calls = []
    end

    def send(to:, body:)
      @calls << {to: to, body: body}
    end
  end

  test "DONE marks the top pending task done and enqueues a next-task notification" do
    user = users(:one)
    top = tasks(:one)
    user.tasks.create!(name: "Walk the dog", position: top.position + 1)

    reply = nil
    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [user.id, top.id]) do
      reply = User::HandleInboundSms.new(user: user, body: "DONE").call
    end

    assert top.reload.done
    assert_equal "Marked \"#{top.name}\" done.", reply
  end

  test "DONE is case-insensitive and ignores surrounding whitespace" do
    user = users(:one)

    reply = User::HandleInboundSms.new(user: user, body: "  done  ").call

    assert tasks(:one).reload.done
    assert_match(/\AMarked/, reply)
  end

  test "DONE with no pending tasks says so without raising or enqueuing a notification" do
    user = users(:one)
    tasks(:one).update!(done: true)

    reply = nil
    assert_no_enqueued_jobs(only: NotifyNextTaskChangedJob) do
      reply = User::HandleInboundSms.new(user: user, body: "DONE").call
    end

    assert_equal "You don't have any pending tasks.", reply
  end

  test "SKIP moves the top task to the bottom of the list and enqueues a next-task notification" do
    user = users(:one)
    top = tasks(:one)
    next_task = user.tasks.create!(name: "Walk the dog", position: top.position + 1)

    reply = nil
    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [user.id, top.id]) do
      reply = User::HandleInboundSms.new(user: user, body: "SKIP").call
    end

    assert_equal next_task, Task.next_for(user)
    assert_equal "Skipped \"#{top.name}\".", reply
  end

  test "NEXT lists up to 5 pending tasks in order without enqueuing a notification" do
    user = users(:one)
    tasks(:one).update!(name: "1st")
    2.upto(6) { |n| user.tasks.create!(name: "#{n}th", position: n) }

    reply = nil
    assert_no_enqueued_jobs(only: NotifyNextTaskChangedJob) do
      reply = User::HandleInboundSms.new(user: user, body: "NEXT").call
    end

    assert_equal "1. 1st\n2. 2th\n3. 3th\n4. 4th\n5. 5th", reply
  end

  test "NEXT excludes done tasks" do
    user = users(:one)
    tasks(:one).update!(done: true)

    reply = User::HandleInboundSms.new(user: user, body: "NEXT").call

    assert_equal "You don't have any pending tasks.", reply
  end

  test "LIST lists every pending task, not just the top 5, without enqueuing a notification" do
    user = users(:one)
    tasks(:one).update!(name: "1st")
    2.upto(7) { |n| user.tasks.create!(name: "#{n}th", position: n) }

    reply = nil
    assert_no_enqueued_jobs(only: NotifyNextTaskChangedJob) do
      reply = User::HandleInboundSms.new(user: user, body: "LIST").call
    end

    assert_equal "1. 1st\n2. 2th\n3. 3th\n4. 4th\n5. 5th\n6. 6th\n7. 7th", reply
  end

  test "LIST is case-insensitive and ignores surrounding whitespace" do
    user = users(:one)

    reply = User::HandleInboundSms.new(user: user, body: "  list  ").call

    assert_match(/\A1\. /, reply)
  end

  test "LIST truncates beyond MAX_LIST_SIZE and notes how many more there are" do
    user = users(:one)
    tasks(:one).destroy
    (User::HandleInboundSms::MAX_LIST_SIZE + 3).times { |n| user.tasks.create!(name: "Task #{n}", position: n) }

    reply = User::HandleInboundSms.new(user: user, body: "LIST").call

    lines = reply.lines.map(&:chomp)
    assert_equal User::HandleInboundSms::MAX_LIST_SIZE + 1, lines.size
    assert_equal "...and 3 more.", lines.last
  end

  test "LIST excludes done tasks and says so when none are pending" do
    user = users(:one)
    tasks(:one).update!(done: true)

    reply = User::HandleInboundSms.new(user: user, body: "LIST").call

    assert_equal "You don't have any pending tasks.", reply
  end

  test "ADD creates a new task and enqueues a next-task notification" do
    user = users(:one)

    reply = nil
    assert_enqueued_with(job: NotifyNextTaskChangedJob, args: [user.id, tasks(:one).id]) do
      reply = User::HandleInboundSms.new(user: user, body: "ADD Clean the garage").call
    end

    assert user.tasks.exists?(name: "Clean the garage")
    assert_equal "Added \"Clean the garage\" to your list.", reply
  end

  test "ADD alone, with no task name, is an unrecognized command" do
    user = users(:one)

    reply = User::HandleInboundSms.new(user: user, body: "ADD").call

    assert_match(/didn't understand/, reply)
  end

  test "SNOOZE until tomorrow pauses reminders until 5am the next day in the user's time zone" do
    user = users(:one)
    user.update!(time_zone: "America/New_York")

    travel_to Time.utc(2026, 6, 22, 18, 0, 0) do # 2pm Eastern
      reply = User::HandleInboundSms.new(user: user, body: "SNOOZE until tomorrow").call

      expected = ActiveSupport::TimeZone["America/New_York"].local(2026, 6, 23, 5, 0, 0)
      assert_equal expected, user.reload.snoozed_until
      assert_equal "Reminders snoozed until Tue Jun 23, 05:00 AM.", reply
    end
  end

  test "SNOOZE for N hours pauses reminders for that many hours from now" do
    user = users(:one)

    travel_to Time.utc(2026, 6, 22, 18, 0, 0) do
      User::HandleInboundSms.new(user: user, body: "SNOOZE for 3 hours").call

      assert_equal 3.hours.from_now, user.reload.snoozed_until
    end
  end

  test "SNOOZE for 1 hour (singular) is accepted" do
    user = users(:one)

    travel_to Time.utc(2026, 6, 22, 18, 0, 0) do
      User::HandleInboundSms.new(user: user, body: "SNOOZE for 1 hour").call

      assert_equal 1.hour.from_now, user.reload.snoozed_until
    end
  end

  test "SNOOZE until <N>pm pauses reminders until that time today when it's still in the future" do
    user = users(:one)
    user.update!(time_zone: "America/New_York")

    travel_to ActiveSupport::TimeZone["America/New_York"].local(2026, 6, 22, 10, 0, 0) do
      User::HandleInboundSms.new(user: user, body: "SNOOZE until 4pm").call

      expected = ActiveSupport::TimeZone["America/New_York"].local(2026, 6, 22, 16, 0, 0)
      assert_equal expected, user.reload.snoozed_until
    end
  end

  test "SNOOZE until <N>am rolls over to tomorrow when that time has already passed today" do
    user = users(:one)
    user.update!(time_zone: "America/New_York")

    travel_to ActiveSupport::TimeZone["America/New_York"].local(2026, 6, 22, 10, 0, 0) do
      User::HandleInboundSms.new(user: user, body: "SNOOZE until 9am").call

      expected = ActiveSupport::TimeZone["America/New_York"].local(2026, 6, 23, 9, 0, 0)
      assert_equal expected, user.reload.snoozed_until
    end
  end

  test "SNOOZE until time parsing is forgiving of spacing, case, and minutes" do
    user = users(:one)
    user.update!(time_zone: "America/New_York")

    travel_to ActiveSupport::TimeZone["America/New_York"].local(2026, 6, 22, 10, 0, 0) do
      User::HandleInboundSms.new(user: user, body: "snooze UNTIL 4:30 PM").call

      expected = ActiveSupport::TimeZone["America/New_York"].local(2026, 6, 22, 16, 30, 0)
      assert_equal expected, user.reload.snoozed_until
    end
  end

  test "SNOOZE with no recognizable duration is an unrecognized snooze command" do
    user = users(:one)

    reply = User::HandleInboundSms.new(user: user, body: "SNOOZE whenever").call

    assert_match(/didn't understand/, reply)
    assert_nil user.reload.snoozed_until
  end

  test "SNOOZE alone, with no duration, returns usage help" do
    user = users(:one)

    reply = User::HandleInboundSms.new(user: user, body: "SNOOZE").call

    assert_match(/didn't understand/, reply)
    assert_nil user.reload.snoozed_until
  end

  test "UNSNOOZE cancels an active snooze" do
    user = users(:one)
    user.update!(snoozed_until: 1.hour.from_now)

    reply = User::HandleInboundSms.new(user: user, body: "UNSNOOZE").call

    assert_equal "Reminders un-snoozed.", reply
    assert_nil user.reload.snoozed_until
  end

  test "UNSNOOZE is case-insensitive and ignores surrounding whitespace" do
    user = users(:one)
    user.update!(snoozed_until: 1.hour.from_now)

    reply = User::HandleInboundSms.new(user: user, body: "  unsnooze  ").call

    assert_equal "Reminders un-snoozed.", reply
    assert_nil user.reload.snoozed_until
  end

  test "UNSNOOZE when not currently snoozed says so without raising" do
    user = users(:one)

    reply = User::HandleInboundSms.new(user: user, body: "UNSNOOZE").call

    assert_equal "You're not currently snoozed.", reply
  end

  test "an unrecognized message returns a help reply" do
    user = users(:one)

    reply = User::HandleInboundSms.new(user: user, body: "huh?").call

    assert_match(/didn't understand/, reply)
  end

  test "logs the inbound text and the outbound reply" do
    user = users(:one)

    assert_difference -> { user.messages.count }, 2 do
      User::HandleInboundSms.new(user: user, body: "  done  ").call
    end

    inbound, outbound = user.messages.order(:created_at).last(2)
    assert inbound.inbound?
    assert_equal "done", inbound.body
    assert outbound.outbound?
    assert_match(/\AMarked/, outbound.body)
  end

  test "deliver_reply: true sends the reply as a real text via the sender, then logs it" do
    user = users(:one)
    top = tasks(:one)
    fake_sender = FakeSender.new

    assert_difference -> { user.messages.count }, 2 do
      User::HandleInboundSms.new(user: user, body: "DONE", deliver_reply: true, sender: fake_sender).call
    end

    assert_equal 1, fake_sender.calls.size
    assert_equal user.phone_number, fake_sender.calls.first[:to]
    assert_equal "Marked \"#{top.name}\" done.", fake_sender.calls.first[:body]

    outbound = user.messages.order(:created_at).last
    assert outbound.outbound?
    assert_equal "Marked \"#{top.name}\" done.", outbound.body
  end

  test "deliver_reply: true does not log the reply if the send raises" do
    user = users(:one)
    failing_sender = Object.new
    def failing_sender.send(**)
      raise Twilio::REST::RestError.new("boom", Twilio::Response.new(500, "{}"))
    end

    assert_difference -> { user.messages.count }, 1 do
      assert_raises(Twilio::REST::RestError) do
        User::HandleInboundSms.new(user: user, body: "DONE", deliver_reply: true, sender: failing_sender).call
      end
    end

    assert_equal ["DONE"], user.messages.order(:created_at).pluck(:body)
  end
end
