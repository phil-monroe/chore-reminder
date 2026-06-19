require "test_helper"

class NotifyNextTaskChangedJobTest < ActiveJob::TestCase
  def with_sender(sender)
    original = NotifyNextTaskChangedJob.sender_factory
    NotifyNextTaskChangedJob.sender_factory = -> { sender }
    yield
  ensure
    NotifyNextTaskChangedJob.sender_factory = original
  end

  test "texts the user when the next task differs from the given previous id" do
    user = users(:one)
    user.tasks.destroy_all
    next_task = user.tasks.create!(name: "Walk the dog")
    fake_sender = User::SendMessageTest::FakeSender.new

    with_sender(fake_sender) { NotifyNextTaskChangedJob.perform_now(user.id, -1) }

    assert_equal 1, fake_sender.calls.size
    assert_includes fake_sender.calls.first[:body], next_task.name
  end

  test "no-ops when the next task is unchanged" do
    user = users(:one)
    current_next = Task.next_for(user)
    fake_sender = User::SendMessageTest::FakeSender.new

    with_sender(fake_sender) { NotifyNextTaskChangedJob.perform_now(user.id, current_next.id) }

    assert_empty fake_sender.calls
  end

  test "retries on Twilio::REST::RestError instead of raising" do
    user = users(:one)
    user.tasks.destroy_all
    user.tasks.create!(name: "Walk the dog")
    failing_sender = Object.new
    def failing_sender.send(**)
      raise Twilio::REST::RestError.new("boom", Twilio::Response.new(500, "{}"))
    end

    with_sender(failing_sender) do
      assert_enqueued_with(job: NotifyNextTaskChangedJob) do
        NotifyNextTaskChangedJob.perform_now(user.id, -1)
      end
    end
  end
end
