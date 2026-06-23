require "test_helper"

class TaskDefinition::AdvanceNextGenerateAtTest < ActiveSupport::TestCase
  test "moves next_generate_at forward by one day" do
    td = task_definitions(:one)
    original = td.next_generate_at

    TaskDefinition::AdvanceNextGenerateAt.new(task_definition: td).call

    assert_equal original + 1.day, td.reload.next_generate_at
  end
end
