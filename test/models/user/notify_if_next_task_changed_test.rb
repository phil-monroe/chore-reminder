require "test_helper"

class User::NotifyIfNextTaskChangedTest < ActiveSupport::TestCase
  test "texts the new next task's reminder body when the next task id is different" do
    user = users(:one)
    user.tasks.destroy_all
    new_next = user.tasks.create!(name: "Walk the dog")
    fake_sender = User::SendMessageTest::FakeSender.new

    User::NotifyIfNextTaskChanged.new(user: user, previous_next_task_id: -1, sender: fake_sender).call

    assert_equal 1, fake_sender.calls.size
    assert_equal user.phone_number, fake_sender.calls.first[:to]
    assert_includes fake_sender.calls.first[:body], new_next.name
  end

  test "does nothing when the next task id is unchanged" do
    user = users(:one)
    current_next = Task.next_for(user)
    fake_sender = User::SendMessageTest::FakeSender.new

    User::NotifyIfNextTaskChanged.new(user: user, previous_next_task_id: current_next.id, sender: fake_sender).call

    assert_empty fake_sender.calls
  end

  test "texts a 'no more tasks' message when there is no longer a next task" do
    user = users(:one)
    previous = Task.next_for(user)
    user.tasks.destroy_all
    fake_sender = User::SendMessageTest::FakeSender.new

    User::NotifyIfNextTaskChanged.new(user: user, previous_next_task_id: previous.id, sender: fake_sender).call

    assert_equal 1, fake_sender.calls.size
    assert_equal "No more tasks!", fake_sender.calls.first[:body]
  end

  test "does nothing when the user is snoozed, even if the next task id changed" do
    user = users(:one)
    user.tasks.destroy_all
    user.tasks.create!(name: "Walk the dog")
    user.update!(snoozed_until: 1.hour.from_now)
    fake_sender = User::SendMessageTest::FakeSender.new

    User::NotifyIfNextTaskChanged.new(user: user, previous_next_task_id: -1, sender: fake_sender).call

    assert_empty fake_sender.calls
  end

  test "does nothing when there was no next task before and there still isn't one" do
    user = users(:one)
    user.tasks.destroy_all
    fake_sender = User::SendMessageTest::FakeSender.new

    User::NotifyIfNextTaskChanged.new(user: user, previous_next_task_id: nil, sender: fake_sender).call

    assert_empty fake_sender.calls
  end
end
