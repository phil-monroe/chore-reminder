require "test_helper"

class ReminderDefinitionTest < ActiveSupport::TestCase
  test "next_send_at is set to today when the time of day has not yet passed" do
    travel_to Time.zone.local(2026, 6, 17, 6, 0, 0) do
      rd = ReminderDefinition.create!(user: users(:one), time_of_day: "08:00")
      assert_equal Time.zone.local(2026, 6, 17, 8, 0, 0), rd.next_send_at
    end
  end

  test "next_send_at is set to tomorrow when the time of day has already passed today" do
    travel_to Time.zone.local(2026, 6, 17, 10, 0, 0) do
      rd = ReminderDefinition.create!(user: users(:one), time_of_day: "08:00")
      assert_equal Time.zone.local(2026, 6, 18, 8, 0, 0), rd.next_send_at
    end
  end

  test "next_send_at recomputes when time_of_day is edited" do
    travel_to Time.zone.local(2026, 6, 17, 6, 0, 0) do
      rd = ReminderDefinition.create!(user: users(:one), time_of_day: "08:00")
      rd.update!(time_of_day: "07:00")
      assert_equal Time.zone.local(2026, 6, 17, 7, 0, 0), rd.next_send_at
    end
  end

  test "advance! moves next_send_at forward by one day" do
    rd = reminder_definitions(:one)
    original = rd.next_send_at
    rd.advance!
    assert_equal original + 1.day, rd.next_send_at
  end
end
