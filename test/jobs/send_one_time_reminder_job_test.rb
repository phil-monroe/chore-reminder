require "test_helper"

class SendOneTimeReminderJobTest < ActiveJob::TestCase
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
    original = SendOneTimeReminderJob.sender_factory
    SendOneTimeReminderJob.sender_factory = -> { sender }
    yield
  ensure
    SendOneTimeReminderJob.sender_factory = original
  end

  test "sends the user's next pending task" do
    user = users(:one)
    user.tasks.destroy_all
    user.tasks.create!(name: "Water plants")

    fake_sender = FakeSender.new
    with_sender(fake_sender) { SendOneTimeReminderJob.perform_now(user.id) }

    assert_equal 1, fake_sender.calls.size
    assert_equal user.phone_number, fake_sender.calls.first[:to]
    assert_equal "Up next: Water plants", fake_sender.calls.first[:body]
  end

  test "no-ops when the user has no pending tasks" do
    user = users(:one)
    user.tasks.destroy_all

    fake_sender = FakeSender.new
    with_sender(fake_sender) { SendOneTimeReminderJob.perform_now(user.id) }

    assert_empty fake_sender.calls
  end

  test "sends even when the user is snoozed, unlike the recurring reminder" do
    user = users(:one)
    user.tasks.destroy_all
    user.tasks.create!(name: "Water plants")
    user.update!(snoozed_until: 1.hour.from_now)

    fake_sender = FakeSender.new
    with_sender(fake_sender) { SendOneTimeReminderJob.perform_now(user.id) }

    assert_equal 1, fake_sender.calls.size
  end

  test "retries on Twilio::REST::RestError instead of raising" do
    user = users(:one)
    user.tasks.destroy_all
    user.tasks.create!(name: "Water plants")

    with_sender(FailingSender.new) do
      assert_enqueued_with(job: SendOneTimeReminderJob) do
        SendOneTimeReminderJob.perform_now(user.id)
      end
    end
  end
end
