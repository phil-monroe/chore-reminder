require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid with name, E.164 phone, and parseable liquid template" do
    user = User.new(name: "Sam", phone_number: "+15555550199", message_template: "{{ task_name }}")
    assert user.valid?
  end

  test "invalid without a name" do
    user = User.new(name: nil, phone_number: "+15555550199", message_template: "{{ task_name }}")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "invalid with a malformed phone number" do
    user = User.new(name: "Sam", phone_number: "555-0199", message_template: "{{ task_name }}")
    assert_not user.valid?
    assert_includes user.errors[:phone_number], "is invalid"
  end

  test "defaults to America/New_York" do
    user = User.new(name: "Sam", phone_number: "+15555550199", message_template: "{{ task_name }}")
    assert_equal "America/New_York", user.time_zone
  end

  test "invalid with a time_zone that isn't a recognized identifier" do
    user = User.new(name: "Sam", phone_number: "+15555550199", message_template: "{{ task_name }}", time_zone: "Mars/Olympus_Mons")
    assert_not user.valid?
    assert_includes user.errors[:time_zone], "is not included in the list"
  end

  test "invalid with a message_template that is not valid liquid" do
    user = User.new(name: "Sam", phone_number: "+15555550199", message_template: "{% if %}")
    assert_not user.valid?
    assert user.errors[:message_template].any? { |msg| msg.include?("not valid Liquid") }
  end

  test "default message_template renders task_name and link" do
    user = users(:one)
    rendered = Liquid::Template.parse(user.message_template).render("task_name" => "Sweep", "link" => "http://example.com")
    assert_equal "Sweep\n\nhttp://example.com", rendered
  end

  test "default message_template renders cleanly with no link" do
    user = users(:one)
    rendered = Liquid::Template.parse(user.message_template).render("task_name" => "Sweep", "link" => nil)
    assert_equal "Sweep\n\n", rendered
  end
end
