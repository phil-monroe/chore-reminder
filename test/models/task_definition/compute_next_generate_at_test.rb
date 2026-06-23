require "test_helper"

class TaskDefinition::ComputeNextGenerateAtTest < ActiveSupport::TestCase
  test "sets next_generate_at to today when the time of day has not yet passed" do
    travel_to Time.zone.local(2026, 6, 17, 6, 0, 0) do
      td = task_definitions(:one)
      td.time_of_day = "08:00"
      TaskDefinition::ComputeNextGenerateAt.new(task_definition: td).call
      assert_equal Time.zone.local(2026, 6, 17, 8, 0, 0), td.next_generate_at
    end
  end

  test "sets next_generate_at to tomorrow when the time of day has already passed today" do
    travel_to Time.zone.local(2026, 6, 17, 10, 0, 0) do
      td = task_definitions(:one)
      td.time_of_day = "08:00"
      TaskDefinition::ComputeNextGenerateAt.new(task_definition: td).call
      assert_equal Time.zone.local(2026, 6, 18, 8, 0, 0), td.next_generate_at
    end
  end

  test "is computed in the user's time zone, not the app default" do
    td = task_definitions(:one)
    td.user.update!(time_zone: "America/New_York")

    travel_to Time.zone.local(2026, 6, 17, 11, 0, 0) do # 7:00 AM Eastern
      td.time_of_day = "08:00"
      TaskDefinition::ComputeNextGenerateAt.new(task_definition: td).call
      assert_equal Time.zone.local(2026, 6, 17, 12, 0, 0), td.next_generate_at # 8:00 AM Eastern == 12:00 UTC
    end
  end
end
