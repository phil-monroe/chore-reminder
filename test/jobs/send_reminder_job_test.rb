require "test_helper"

class SendReminderJobTest < ActiveJob::TestCase
  class FakeSender
    attr_reader :calls

    def initialize
      @calls = []
    end

    def send(to:, body:)
      @calls << {to: to, body: body}
    end
  end

  class FailingSender
    def send(to:, body:)
      raise Twilio::REST::RestError.new("boom", Twilio::Response.new(500, "{}"))
    end
  end

  def with_sender(sender)
    original = SendReminderJob.sender_factory
    SendReminderJob.sender_factory = -> { sender }
    yield
  ensure
    SendReminderJob.sender_factory = original
  end

  test "sends the next pending task with a link when it has a task_definition" do
    reminder = reminder_definitions(:one)
    user = reminder.user
    user.tasks.destroy_all
    user.tasks.create!(name: "Feed the pets", task_definition: task_definitions(:one).tap { |td| td.update!(user: user) })

    fake_sender = FakeSender.new
    with_sender(fake_sender) { SendReminderJob.perform_now(reminder.id) }

    assert_equal 1, fake_sender.calls.size
    assert_equal user.phone_number, fake_sender.calls.first[:to]
    assert_includes fake_sender.calls.first[:body], "Feed the pets"
    assert_includes fake_sender.calls.first[:body], "http://"
  end

  test "sends the next pending task with no link when it is an ad-hoc task" do
    reminder = reminder_definitions(:one)
    user = reminder.user
    user.tasks.destroy_all
    user.tasks.create!(name: "Water plants")

    fake_sender = FakeSender.new
    with_sender(fake_sender) { SendReminderJob.perform_now(reminder.id) }

    assert_equal 1, fake_sender.calls.size
    assert_equal "Up next: Water plants", fake_sender.calls.first[:body]
  end

  test "sends the time estimate when the template references it and the task has one" do
    reminder = reminder_definitions(:one)
    user = reminder.user
    user.update!(message_template: "Up next: {{ task_name }}{% if time_estimate %} ({{ time_estimate }}){% endif %}")
    user.tasks.destroy_all
    user.tasks.create!(name: "Water plants", time_estimate_minutes: 10)

    fake_sender = FakeSender.new
    with_sender(fake_sender) { SendReminderJob.perform_now(reminder.id) }

    assert_equal "Up next: Water plants (10 min)", fake_sender.calls.first[:body]
  end

  test "no-ops when the user has no pending tasks" do
    reminder = reminder_definitions(:one)
    reminder.user.tasks.destroy_all

    fake_sender = FakeSender.new
    with_sender(fake_sender) { SendReminderJob.perform_now(reminder.id) }

    assert_empty fake_sender.calls
  end

  test "no-ops when the user is snoozed" do
    reminder = reminder_definitions(:one)
    reminder.user.tasks.destroy_all
    reminder.user.tasks.create!(name: "Water plants")
    reminder.user.update!(snoozed_until: 1.hour.from_now)

    fake_sender = FakeSender.new
    with_sender(fake_sender) { SendReminderJob.perform_now(reminder.id) }

    assert_empty fake_sender.calls
  end

  test "sends normally once the snooze has lapsed" do
    reminder = reminder_definitions(:one)
    reminder.user.tasks.destroy_all
    reminder.user.tasks.create!(name: "Water plants")
    reminder.user.update!(snoozed_until: 1.hour.ago)

    fake_sender = FakeSender.new
    with_sender(fake_sender) { SendReminderJob.perform_now(reminder.id) }

    assert_equal 1, fake_sender.calls.size
  end

  test "retries on Twilio::REST::RestError instead of raising" do
    reminder = reminder_definitions(:one)
    reminder.user.tasks.destroy_all
    reminder.user.tasks.create!(name: "Water plants")

    with_sender(FailingSender.new) do
      assert_enqueued_with(job: SendReminderJob) do
        SendReminderJob.perform_now(reminder.id)
      end
    end
  end
end
