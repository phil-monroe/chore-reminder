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

  test "invalid with a username containing uppercase or symbols" do
    user = User.new(name: "Sam", phone_number: "+15555550199", message_template: "{{ task_name }}", username: "Sam Jones!")
    assert_not user.valid?
    assert_includes user.errors[:username], "can only contain lowercase letters, numbers, underscores, and hyphens, and can't be purely numeric"
  end

  test "invalid with a purely numeric username" do
    user = User.new(name: "Sam", phone_number: "+15555550199", message_template: "{{ task_name }}", username: "12345")
    assert_not user.valid?
    assert_includes user.errors[:username], "can only contain lowercase letters, numbers, underscores, and hyphens, and can't be purely numeric"
  end

  test "invalid with a username already taken by another user" do
    users(:one).update!(username: "sam")
    user = User.new(name: "Other", phone_number: "+15555550199", message_template: "{{ task_name }}", username: "sam")
    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end

  test "valid with a blank username" do
    user = User.new(name: "Sam", phone_number: "+15555550199", message_template: "{{ task_name }}")
    assert user.valid?
  end

  test "normalizes an autocapitalized or whitespace-padded username before validating" do
    user = User.new(name: "Sam", phone_number: "+15555550199", message_template: "{{ task_name }}", username: " Sam ")
    assert user.valid?
    assert_equal "sam", user.username
  end

  test "to_param returns the username when present, otherwise the id" do
    user = users(:one)
    assert_equal user.id.to_s, user.to_param

    user.update!(username: "alex")
    assert_equal "alex", user.to_param
  end

  test ".find_by_param! finds by username when given a non-numeric param" do
    users(:one).update!(username: "alex")
    assert_equal users(:one), User.find_by_param!("alex")
  end

  test ".find_by_param! finds by id when given a numeric param" do
    assert_equal users(:one), User.find_by_param!(users(:one).id.to_s)
  end
end
